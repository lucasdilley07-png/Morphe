import Foundation
import HealthKit
import WatchConnectivity
import WatchKit

/// Heart rate on the wrist (2026-10-04). While a Morphe session runs, the
/// watch holds a real HealthKit workout session: that is what lets it read
/// live heart rate and keeps the app in front between sets. The workout is
/// SAVED to Apple Health only when the phone's "Sync to Health" is on;
/// otherwise it is discarded at the end and nothing is written.
final class WatchWorkoutRecorder: NSObject, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var saveOnEnd = false
    private var ceiling: Timer?

    /// Main-thread callbacks.
    var onHeartRate: ((Int) -> Void)?
    var onCalories: ((Int) -> Void)?
    var onRecording: ((Bool) -> Void)?

    var isRunning: Bool { session != nil }

    func start(saveToHealth: Bool) {
        saveOnEnd = saveToHealth
        guard HKHealthStore.isHealthDataAvailable(), session == nil else { return }
        let share: Set<HKSampleType> = [HKObjectType.workoutType()]
        let read: Set<HKObjectType> = [HKQuantityType(.heartRate), HKQuantityType(.activeEnergyBurned)]
        healthStore.requestAuthorization(toShare: share, read: read) { [weak self] granted, _ in
            DispatchQueue.main.async {
                guard granted else { return }
                self?.begin()
            }
        }
    }

    private func begin() {
        guard session == nil else { return }
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor
        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
            session.delegate = self
            builder.delegate = self
            self.session = session
            self.builder = builder
            let now = Date()
            session.startActivity(with: now)
            builder.beginCollection(withStart: now) { [weak self] began, _ in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if began {
                        self.onRecording?(true)
                    } else {
                        // Permission refused or Health busy: no session,
                        // no heart rate, and the wrist logger works as before.
                        self.session?.end()
                        self.session = nil
                        self.builder = nil
                    }
                }
            }
            // A session the watch never hears the end of must not record
            // all night.
            ceiling?.invalidate()
            let timer = Timer(timeInterval: 4 * 60 * 60, repeats: false) { [weak self] _ in
                DispatchQueue.main.async { self?.stop() }
            }
            ceiling = timer
            RunLoop.main.add(timer, forMode: .common)
        } catch {
            session = nil
            builder = nil
        }
    }

    func stop() {
        ceiling?.invalidate()
        ceiling = nil
        guard let session, let builder else { return }
        let save = saveOnEnd
        self.session = nil
        self.builder = nil
        session.end()
        builder.endCollection(withEnd: Date()) { _, _ in
            if save {
                builder.finishWorkout { _, _ in }
            } else {
                builder.discardWorkout()
            }
        }
        onRecording?(false)
        onHeartRate?(0)
    }

    // MARK: HKLiveWorkoutBuilderDelegate

    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        let heartRate = HKQuantityType(.heartRate)
        let energy = HKQuantityType(.activeEnergyBurned)
        if collectedTypes.contains(heartRate),
           let value = workoutBuilder.statistics(for: heartRate)?.mostRecentQuantity()?
            .doubleValue(for: HKUnit.count().unitDivided(by: .minute())) {
            DispatchQueue.main.async { [weak self] in self?.onHeartRate?(Int(value.rounded())) }
        }
        if collectedTypes.contains(energy),
           let value = workoutBuilder.statistics(for: energy)?.sumQuantity()?.doubleValue(for: .kilocalorie()) {
            DispatchQueue.main.async { [weak self] in self?.onCalories?(Int(value.rounded())) }
        }
    }

    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    // MARK: HKWorkoutSessionDelegate

    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState,
                        from fromState: HKWorkoutSessionState, date: Date) {}

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        DispatchQueue.main.async { [weak self] in self?.stop() }
    }
}

/// Watch-side session state: a mirror of the phone store's snapshot plus
/// the local rest countdown (rest runs on the wrist so it keeps ticking
/// when the phone is racked across the gym).
final class WatchSessionModel: NSObject, ObservableObject, WCSessionDelegate {

    @Published var sessionActive = false
    @Published var workoutName = ""
    @Published var workoutComplete = false
    @Published var exerciseName = ""
    @Published var exerciseIndex = 0
    @Published var totalExercises = 0
    @Published var setsDone = 0
    @Published var setsTarget = 0
    @Published var reps = 10
    @Published var weight: Double = 0
    @Published var unit = "lb"
    @Published var restSeconds = 180
    @Published var lastLine: String?
    @Published var canPrev = false
    @Published var isReachable = false
    @Published var sending = false
    /// Phone-side explanation for a refused command (audit 16: a failure
    /// buzz with no reason looked broken).
    @Published var notice: String?

    /// Live from the watch's own sensors while a session runs; 0 = no
    /// reading (not recording, or permission refused).
    @Published var heartRate = 0
    @Published var activeCalories = 0
    private let recorder = WatchWorkoutRecorder()
    /// The phone's "Sync to Health" setting, mirrored in the snapshot.
    private var healthSync = false

    /// Non-nil while resting; the view derives the ring from it.
    @Published var restEndDate: Date?
    private var restTimer: Timer?
    private var lastSequence = 0

    override init() {
        super.init()
        recorder.onHeartRate = { [weak self] bpm in self?.heartRate = bpm }
        recorder.onCalories = { [weak self] kcal in self?.activeCalories = kcal }
        recorder.onRecording = { [weak self] recording in
            guard let self else { return }
            // The phone skips its own Health write while the wrist is
            // recording one — one workout in Health, not two.
            if recording, self.healthSync { self.send(["cmd": "recording", "on": true]) }
            if !recording { self.activeCalories = 0 }
        }
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    var weightStep: Double { unit == "kg" ? 2.5 : 5 }

    var weightLabel: String {
        weight > 0
            ? "\(weight.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(weight)) : String(weight)) \(unit)"
            : "BW"
    }

    // MARK: Commands (all round-trip through the phone store)

    func logSet() {
        // Capture BEFORE the reply applies (audit 16, P2): the snapshot in
        // the reply may already carry the NEXT exercise's rest length.
        let restLength = restSeconds
        send(["cmd": "logSet", "reps": reps, "weight": weight]) { [weak self] reply in
            guard let self else { return }
            if reply["logged"] as? Bool == true {
                WKInterfaceDevice.current().play(.success)
                self.beginRest(seconds: restLength)
            } else {
                WKInterfaceDevice.current().play(.failure)
            }
        }
    }

    func next() { send(["cmd": "next"]) }
    func previous() { send(["cmd": "prev"]) }
    func startWorkout() { send(["cmd": "start"]) }

    func skipRest() {
        restTimer?.invalidate()
        restTimer = nil
        restEndDate = nil
    }

    private func beginRest(seconds: Int) {
        guard seconds > 0 else { return }
        restEndDate = Date().addingTimeInterval(TimeInterval(seconds))
        restTimer?.invalidate()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self, let end = self.restEndDate else { return }
                if end <= Date() {
                    self.skipRest()
                    WKInterfaceDevice.current().play(.notification)
                }
            }
        }
        restTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func send(_ message: [String: Any],
                      completion: (([String: Any]) -> Void)? = nil) {
        guard WCSession.default.activationState == .activated else { return }
        sending = true
        WCSession.default.sendMessage(message, replyHandler: { [weak self] reply in
            DispatchQueue.main.async {
                self?.sending = false
                self?.apply(reply)
                completion?(reply)
            }
        }, errorHandler: { [weak self] _ in
            DispatchQueue.main.async {
                self?.sending = false
                WKInterfaceDevice.current().play(.retry)
            }
        })
    }

    private func apply(_ snapshot: [String: Any]) {
        // Out-of-order guard: applicationContext and message replies race.
        if let seq = snapshot["seq"] as? Int {
            guard seq >= lastSequence else { return }
            lastSequence = seq
        }
        let previousExercise = exerciseName
        if let value = snapshot["healthSync"] as? Bool { healthSync = value }
        if let value = snapshot["sessionActive"] as? Bool {
            if value, !recorder.isRunning {
                recorder.start(saveToHealth: healthSync)
            } else if !value, recorder.isRunning {
                recorder.stop()
            }
            sessionActive = value
        }
        if let value = snapshot["workoutName"] as? String { workoutName = value }
        if let value = snapshot["workoutComplete"] as? Bool { workoutComplete = value }
        if let value = snapshot["exerciseName"] as? String { exerciseName = value }
        if let value = snapshot["exerciseIndex"] as? Int { exerciseIndex = value }
        if let value = snapshot["totalExercises"] as? Int { totalExercises = value }
        if let value = snapshot["setsDone"] as? Int { setsDone = value }
        if let value = snapshot["setsTarget"] as? Int { setsTarget = value }
        // Reps/weight prefill only re-seeds when the EXERCISE changed —
        // an incidental phone-side publish must not snap a mid-adjust
        // stepper back (audit 16, P2).
        if exerciseName != previousExercise {
            if let value = snapshot["suggestedReps"] as? Int { reps = value }
            if let value = snapshot["weight"] as? Double { weight = value }
        }
        if let value = snapshot["unit"] as? String { unit = value }
        if let value = snapshot["restSeconds"] as? Int { restSeconds = value }
        if let value = snapshot["canPrev"] as? Bool { canPrev = value }
        lastLine = snapshot["lastLine"] as? String
        notice = snapshot["notice"] as? String
    }

    // MARK: WCSessionDelegate

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        DispatchQueue.main.async { [weak self] in
            self?.isReachable = session.isReachable
            // Whatever the phone last published is the starting state.
            self?.apply(session.receivedApplicationContext)
        }
    }

    func session(_ session: WCSession,
                 didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            self?.apply(applicationContext)
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { [weak self] in
            self?.isReachable = session.isReachable
        }
    }
}
