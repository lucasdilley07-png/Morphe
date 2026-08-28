import Foundation
import WatchConnectivity
import WatchKit

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

    /// Non-nil while resting; the view derives the ring from it.
    @Published var restEndDate: Date?
    private var restTimer: Timer?
    private var lastSequence = 0

    override init() {
        super.init()
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
        if let value = snapshot["sessionActive"] as? Bool { sessionActive = value }
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
