import SwiftUI
import AVFoundation
import Vision

// MARK: - Form Check (Phase 1: framing + live skeleton + rep counting)
//
// On-device ONLY. Vision runs on the raw camera buffer; nothing — least of all
// video — ever leaves the phone. This is the honest core of the camera coach:
// it shows the user in frame with a red/yellow/green distance box, draws their
// skeleton, and counts reps for a curated exercise. It deliberately makes NO
// form-correction claims yet — those are Phase 2 (measurable rule-based cues).
//
// The iOS Simulator has no camera, so `configure()` resolves to `.unavailable`
// there and the screen shows a device-required state. The live pipeline must be
// verified on a physical iPhone.

// MARK: Movement model
//
// Rep counting keys off ONE joint angle per movement pattern. The camera coach
// supports two camera-trackable patterns today; any other exercise falls back
// to the squat (lower-body) tracker. The exercise NAME shown to the user comes
// straight from the active workout, so the header always matches what they're
// actually doing.

enum FormCheckMovement {
    case squat    // knee angle — standing; depth + knee-tracking + tempo
    case pushup   // elbow angle — prone; depth + tempo

    /// Best-guess pattern for a workout exercise: name keywords first, then
    /// muscle group. Defaults to squat (the safe lower-body/compound tracker).
    static func infer(exerciseName name: String, muscleGroup: MuscleGroup) -> FormCheckMovement {
        let n = name.lowercased()
        let pushWords = ["push", "press", "dip", "bench", "overhead", "fly"]
        if pushWords.contains(where: { n.contains($0) }) { return .pushup }
        switch muscleGroup {
        case .chest, .shoulders: return .pushup
        default: return .squat
        }
    }

    var setupHint: String {
        switch self {
        case .squat:  return "Stand facing the camera with your whole body in frame. Move at a steady, controlled tempo."
        case .pushup: return "Rest the phone on the floor to your side so it can see your whole body. Steady tempo."
        }
    }

    var usesValgus: Bool { self == .squat }
}

// MARK: Framing state (the red / yellow / green distance box)

enum FramingState: Equatable {
    case noPerson
    case tooClose   // red — filling too much of the frame
    case tooFar     // yellow — almost there, come closer
    case good       // green — framed for tracking

    var label: String {
        switch self {
        case .noPerson: return "STEP INTO FRAME"
        case .tooClose: return "STEP BACK"
        case .tooFar:   return "MOVE CLOSER"
        case .good:     return "PERFECT — HOLD THERE"
        }
    }

    /// Literal traffic-light semantics per the feature spec. This is a
    /// functional signal, so it steps outside the black+yellow palette on
    /// purpose (red and green carry meaning a monochrome box couldn't).
    var color: Color {
        switch self {
        case .noPerson: return Color.white.opacity(0.35)
        case .tooClose: return Color(red: 0.92, green: 0.26, blue: 0.28)
        case .tooFar:   return Color(red: 0.98, green: 0.78, blue: 0.22)
        case .good:     return Color(red: 0.30, green: 0.85, blue: 0.45)
        }
    }

    var isTrackable: Bool { self == .good }
}

// MARK: Form metrics + rule-based cue analysis (Phase 2)
//
// The analyzer is a PURE function of per-rep metrics — no camera, no state —
// so the advice logic is fully unit-testable even though the pose pipeline
// only runs on a device. Cues are framed as observations + suggestions, never
// diagnoses; form checking is safety-adjacent and the honesty bar is highest
// here.

/// What the camera measured for one rep of a squat.
struct FormRepMetrics: Equatable {
    /// Deepest (smallest) interior knee angle reached. ~90° ≈ parallel.
    var minKneeAngle: CGFloat
    /// Knee-spread ÷ ankle-spread at the bottom. < ~0.85 = knees caving in.
    /// nil when both knees + ankles weren't confidently visible.
    var valgusRatio: CGFloat?
    var descentSeconds: Double
    var ascentSeconds: Double
}

struct FormCue: Equatable {
    enum Category: String { case knees, depth, tempo, consistency }
    enum Tone { case good, suggestion }
    var category: Category
    var tone: Tone
    var message: String
}

/// A single rep's overall form grade — the per-rep pop-up rating.
enum FormRepGrade: String {
    case poor = "Poor"
    case good = "Good"
    case great = "Great"
    case excellent = "Excellent"

    var color: Color {
        switch self {
        case .poor:      return Color(red: 0.92, green: 0.26, blue: 0.28)
        case .good:      return Color(red: 0.98, green: 0.78, blue: 0.22)
        case .great:     return Color(red: 0.45, green: 0.85, blue: 0.48)
        case .excellent: return Color(red: 0.24, green: 0.95, blue: 0.55)
        }
    }
}

struct FormSetSummary: Equatable {
    var reps: Int
    var avgMinKneeAngle: CGFloat
    var bestMinKneeAngle: CGFloat   // smallest angle = deepest rep
    var cues: [FormCue]
}

enum FormAnalyzer {
    // Thresholds are honest heuristics from squat coaching, not medical limits.
    static let shallowAngle: CGFloat = 110      // above this ≈ not yet parallel
    static let valgusRatio: CGFloat = 0.85      // below this ≈ knees caving
    static let fastDescent: Double = 0.6        // faster than this ≈ dropping

    static func analyze(_ metrics: [FormRepMetrics], movement: FormCheckMovement) -> FormSetSummary {
        guard !metrics.isEmpty else {
            return FormSetSummary(reps: 0, avgMinKneeAngle: 0, bestMinKneeAngle: 0, cues: [])
        }
        let n = metrics.count
        let angles = metrics.map(\.minKneeAngle)   // primary depth angle for the movement
        let avg = angles.reduce(0, +) / CGFloat(n)
        let best = angles.min() ?? 0

        var cues: [FormCue] = []

        // Knee tracking is squat-specific and leads (it's injury-relevant).
        // A single front camera reads valgus unreliably, so this only fires on
        // a strong, consistent signal — at least 3 measured reps and a clear
        // majority caving — rather than flagging on noise.
        if movement.usesValgus {
            let valgusValues = metrics.compactMap(\.valgusRatio)
            let caved = valgusValues.filter { $0 < valgusRatio }.count
            if valgusValues.count >= 3, Double(caved) / Double(valgusValues.count) > 0.5 {
                cues.append(FormCue(category: .knees, tone: .suggestion,
                    message: "Push your knees out — they drifted inward on \(caved) rep\(caved == 1 ? "" : "s"), often as you tire."))
            }
        }

        // Depth / range of motion.
        let shallow = angles.filter { $0 > shallowAngle }.count
        if Double(shallow) / Double(n) > 0.4 {
            let msg = movement == .squat
                ? "Try sitting a little lower — \(shallow) of \(n) rep\(n == 1 ? "" : "s") stopped above parallel."
                : "Go a little lower — \(shallow) of \(n) rep\(n == 1 ? "" : "s") were shallow. Aim to bring your chest toward the floor."
            cues.append(FormCue(category: .depth, tone: .suggestion, message: msg))
        } else {
            let msg = movement == .squat
                ? "Good depth — you're getting to about parallel."
                : "Good range — you're getting nice and low."
            cues.append(FormCue(category: .depth, tone: .good, message: msg))
        }

        // Tempo.
        let avgDescent = metrics.map(\.descentSeconds).reduce(0, +) / Double(n)
        if avgDescent > 0, avgDescent < fastDescent {
            cues.append(FormCue(category: .tempo, tone: .suggestion,
                message: "Control the way down — you're dropping fast; aim for about two seconds."))
        }

        // At most three cues so it reads as coaching, not a wall of text.
        return FormSetSummary(reps: n, avgMinKneeAngle: avg, bestMinKneeAngle: best,
                              cues: Array(cues.prefix(3)))
    }

    /// Overall grade for one rep, from depth + (squat) knee tracking + tempo.
    static func grade(_ m: FormRepMetrics, movement: FormCheckMovement) -> FormRepGrade {
        var score = 0
        // Depth / range of motion (the primary angle).
        switch m.minKneeAngle {
        case ..<95:  score += 2   // full, deep rep
        case ..<110: score += 1   // solid
        case ..<125: break        // a touch shallow
        default:     score -= 1   // clearly short
        }
        // Knee tracking (squats only, when measured).
        if movement.usesValgus, let v = m.valgusRatio {
            if v >= 0.90 { score += 1 }
            else if v < valgusRatio { score -= 1 }
        }
        // Tempo — controlled earns, dropping loses.
        if m.descentSeconds >= 0.8 { score += 1 }
        else if m.descentSeconds > 0, m.descentSeconds < 0.4 { score -= 1 }

        switch score {
        case 3...: return .excellent
        case 2:    return .great
        case 1:    return .good
        default:   return .poor
        }
    }

    /// One-line feedback for the rep that just finished (shown live).
    static func liveCue(for m: FormRepMetrics, repNumber: Int, movement: FormCheckMovement) -> String {
        if movement.usesValgus, let v = m.valgusRatio, v < valgusRatio { return "Rep \(repNumber) · knees caved in" }
        if m.minKneeAngle > shallowAngle {
            return "Rep \(repNumber) · \(movement == .squat ? "a little above parallel" : "a little shallow")"
        }
        return "Rep \(repNumber) · clean"
    }
}

// MARK: Persisted form-check history (isolated from the workout-log store)

struct FormCheckResult: Codable, Identifiable, Equatable {
    var id = UUID()
    var date: Double                 // timeIntervalSince1970
    var exercise: String
    var reps: Int
    var avgMinKneeAngle: Double
    var bestMinKneeAngle: Double
    var cues: [String]

    init(id: UUID = UUID(), date: Double, exercise: String, reps: Int,
         avgMinKneeAngle: Double, bestMinKneeAngle: Double, cues: [String]) {
        self.id = id; self.date = date; self.exercise = exercise; self.reps = reps
        self.avgMinKneeAngle = avgMinKneeAngle; self.bestMinKneeAngle = bestMinKneeAngle; self.cues = cues
    }

    // Tolerant decode — one bad field can't nil the whole history.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = ((try? c.decodeIfPresent(UUID.self, forKey: .id)) ?? nil) ?? UUID()
        date = ((try? c.decodeIfPresent(Double.self, forKey: .date)) ?? nil) ?? 0
        exercise = ((try? c.decodeIfPresent(String.self, forKey: .exercise)) ?? nil) ?? "Squat"
        reps = ((try? c.decodeIfPresent(Int.self, forKey: .reps)) ?? nil) ?? 0
        avgMinKneeAngle = ((try? c.decodeIfPresent(Double.self, forKey: .avgMinKneeAngle)) ?? nil) ?? 0
        bestMinKneeAngle = ((try? c.decodeIfPresent(Double.self, forKey: .bestMinKneeAngle)) ?? nil) ?? 0
        cues = ((try? c.decodeIfPresent([String].self, forKey: .cues)) ?? nil) ?? []
    }
}

/// Standalone, versioned, tolerant persistence — deliberately NOT wired into
/// the god-object store or the workout-log/streak/XP paths.
final class FormCheckFilePersistence {
    private struct Wrapper: Codable { var schemaVersion: Int; var results: [FormCheckResult] }
    private let url: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(directoryName: String = "MorpheStore") {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory,
                                                 in: .userDomainMask, appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent(directoryName, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        url = dir.appendingPathComponent("form-check-history.json")
    }

    func load() -> [FormCheckResult] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        if let w = try? decoder.decode(Wrapper.self, from: data) { return w.results }
        return []   // unreadable → empty, never a crash
    }

    func append(_ result: FormCheckResult) {
        var all = load()
        all.insert(result, at: 0)
        if let data = try? encoder.encode(Wrapper(schemaVersion: 1, results: all)) {
            try? data.write(to: url, options: [.atomic])
        }
    }

    /// Deepest rep ever recorded (smallest angle), for the "personal best" line.
    func bestDepthAngle() -> Double? {
        load().map(\.bestMinKneeAngle).filter { $0 > 0 }.min()
    }

    func clear() { try? FileManager.default.removeItem(at: url) }
}

// MARK: Camera + Vision session

@Observable
final class FormCheckSession: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    enum Availability { case unknown, authorized, denied, unavailable }

    // Observed UI state (always mutated on the main actor).
    private(set) var availability: Availability = .unknown
    private(set) var isRunning = false
    private(set) var framing: FramingState = .noPerson
    private(set) var repCount = 0
    /// Detected joints in view space: normalized (0...1), top-left origin,
    /// already mirrored to match the front-camera preview.
    private(set) var joints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]

    let exerciseName: String
    let movement: FormCheckMovement
    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "com.morpheapp.formcheck.session")
    private let videoQueue = DispatchQueue(label: "com.morpheapp.formcheck.video")
    private let poseRequest = VNDetectHumanBodyPoseRequest()
    private var isConfigured = false

    // Per-rep feedback (Phase 2).
    private(set) var repMetrics: [FormRepMetrics] = []
    private(set) var liveCue: String?
    private(set) var lastRepGrade: FormRepGrade?

    // Rep-counting + metric-capture state machine (knee-angle based, squat).
    private var repPhase: RepPhase = .up
    private enum RepPhase { case up, down }
    private var descentStartT: Double?
    private var minAngleThisRep: CGFloat = .greatestFiniteMagnitude
    private var bottomT: Double = 0
    private var bottomPose: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
    private var recentAngles: [CGFloat] = []   // median-of-3 smoothing buffer
    private let history = FormCheckFilePersistence()

    init(exerciseName: String, movement: FormCheckMovement) {
        self.exerciseName = exerciseName
        self.movement = movement
        super.init()
    }

    // MARK: Lifecycle

    func configure() {
        guard !isConfigured else { start(); return }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            buildSessionAndStart()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted { self?.buildSessionAndStart() }
                    else { self?.availability = .denied }
                }
            }
        default:
            availability = .denied
        }
    }

    private func buildSessionAndStart() {
        sessionQueue.async { [weak self] in
            guard let self else { return }

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                  let input = try? AVCaptureDeviceInput(device: device),
                  self.session.canAddInput(input)
            else {
                DispatchQueue.main.async { self.availability = .unavailable }
                return
            }

            self.session.beginConfiguration()
            self.session.sessionPreset = .high
            self.session.addInput(input)

            let output = AVCaptureVideoDataOutput()
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(self, queue: self.videoQueue)
            if self.session.canAddOutput(output) {
                self.session.addOutput(output)
            }
            if let connection = output.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90  // portrait
            }
            self.session.commitConfiguration()
            self.isConfigured = true

            self.session.startRunning()
            DispatchQueue.main.async {
                self.availability = .authorized
                self.isRunning = true
            }
        }
    }

    func start() {
        guard isConfigured, !session.isRunning else { return }
        sessionQueue.async { [weak self] in
            self?.session.startRunning()
            DispatchQueue.main.async { self?.isRunning = true }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            if self?.session.isRunning == true { self?.session.stopRunning() }
            DispatchQueue.main.async { self?.isRunning = false }
        }
    }

    func resetReps() {
        repCount = 0
        repPhase = .up
        descentStartT = nil
        minAngleThisRep = .greatestFiniteMagnitude
        recentAngles = []
        repMetrics = []
        liveCue = nil
        lastRepGrade = nil
    }

    /// Ends the set, analyzes it, persists the result, and returns the summary
    /// plus the all-time best depth angle for the review screen.
    func finishSet() -> (summary: FormSetSummary, bestEverAngle: Double?) {
        stop()
        let summary = FormAnalyzer.analyze(repMetrics, movement: movement)
        if summary.reps > 0 {
            history.append(FormCheckResult(
                date: Date().timeIntervalSince1970,
                exercise: exerciseName,
                reps: summary.reps,
                avgMinKneeAngle: Double(summary.avgMinKneeAngle),
                bestMinKneeAngle: Double(summary.bestMinKneeAngle),
                cues: summary.cues.map(\.message)))
        }
        return (summary, history.bestDepthAngle())
    }

    // MARK: Frame processing

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let frameTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        try? handler.perform([poseRequest])

        guard let observation = poseRequest.results?.first,
              let points = try? observation.recognizedPoints(.all) else {
            DispatchQueue.main.async { [weak self] in
                self?.joints = [:]
                self?.framing = .noPerson
            }
            return
        }

        // Vision: normalized, bottom-left origin. Convert to top-left and
        // mirror X so the overlay lines up with the mirrored front preview.
        // 0.5 confidence (up from 0.3) keeps low-certainty joints out of the
        // angle math — the biggest source of inaccurate depth/knee readings.
        var mapped: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
        for (name, point) in points where point.confidence > 0.5 {
            mapped[name] = CGPoint(x: 1 - point.location.x, y: 1 - point.location.y)
        }

        let framing = framingState(for: mapped)
        let newRep = updateReps(with: mapped, time: frameTime)

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.joints = mapped
            self.framing = framing
            if let metrics = newRep {
                self.repMetrics.append(metrics)
                self.repCount += 1
                self.lastRepGrade = FormAnalyzer.grade(metrics, movement: self.movement)
                self.liveCue = FormAnalyzer.liveCue(for: metrics, repNumber: self.repCount, movement: self.movement)
                Haptics.impact(.light)
            }
        }
    }

    // MARK: Framing

    private func framingState(for joints: [VNHumanBodyPoseObservation.JointName: CGPoint]) -> FramingState {
        guard joints.count >= 6 else { return .noPerson }
        switch movement {
        case .squat:
            // Standing: judge distance by how much of the frame height the body fills.
            let ys = joints.values.map(\.y)
            guard let top = ys.min(), let bottom = ys.max() else { return .noPerson }
            let bodyHeight = bottom - top
            switch bodyHeight {
            case 0.92...:      return .tooClose
            case 0.60..<0.92:  return .good
            default:           return .tooFar
            }
        case .pushup:
            // Prone: height isn't meaningful — good once the tracked arm is visible.
            return primaryAngle(from: joints) != nil ? .good : .tooFar
        }
    }

    // MARK: Reps (movement-aware joint-angle state machine)
    //
    // Rep counting is NOT gated on perfect framing — it fires whenever the
    // movement's primary joints are detected. (The old squat-only version
    // required the green "good" box, so a push-up, where the body is low and
    // horizontal, could never count.)

    private func updateReps(with joints: [VNHumanBodyPoseObservation.JointName: CGPoint],
                            time t: Double) -> FormRepMetrics? {
        guard let raw = primaryAngle(from: joints) else { return nil }

        // Median-of-3 smoothing: rejects the single-frame angle spikes that
        // otherwise make depth read far deeper or shallower than reality.
        recentAngles.append(raw)
        if recentAngles.count > 3 { recentAngles.removeFirst() }
        let angle = recentAngles.sorted()[recentAngles.count / 2]

        switch repPhase {
        case .up:
            if angle > 155 {
                // Extended / between reps — reset the accumulator.
                descentStartT = nil
                minAngleThisRep = .greatestFiniteMagnitude
            } else {
                if descentStartT == nil { descentStartT = t }   // movement begun
                if angle < minAngleThisRep {
                    minAngleThisRep = angle; bottomT = t; bottomPose = joints
                }
                if angle < 100 { repPhase = .down }              // deep enough to count
            }
        case .down:
            if angle < minAngleThisRep {
                minAngleThisRep = angle; bottomT = t; bottomPose = joints
            }
            if angle > 155 {
                let metrics = FormRepMetrics(
                    minKneeAngle: minAngleThisRep,
                    valgusRatio: movement.usesValgus ? Self.valgusRatio(from: bottomPose) : nil,
                    descentSeconds: max(0, bottomT - (descentStartT ?? bottomT)),
                    ascentSeconds: max(0, t - bottomT))
                repPhase = .up
                descentStartT = nil
                minAngleThisRep = .greatestFiniteMagnitude
                return metrics
            }
        }
        return nil
    }

    /// The angle that opens and closes once per rep: knee for the squat, elbow
    /// for the push-up, preferring whichever side is more confidently visible.
    private func primaryAngle(from joints: [VNHumanBodyPoseObservation.JointName: CGPoint]) -> CGFloat? {
        switch movement {
        case .squat:
            return Self.jointAngle(joints, .leftHip, .leftKnee, .leftAnkle)
                ?? Self.jointAngle(joints, .rightHip, .rightKnee, .rightAnkle)
        case .pushup:
            return Self.jointAngle(joints, .leftShoulder, .leftElbow, .leftWrist)
                ?? Self.jointAngle(joints, .rightShoulder, .rightElbow, .rightWrist)
        }
    }

    /// Interior angle (degrees) at joint `b` formed by a–b–c.
    private static func jointAngle(_ joints: [VNHumanBodyPoseObservation.JointName: CGPoint],
                                   _ a: VNHumanBodyPoseObservation.JointName,
                                   _ b: VNHumanBodyPoseObservation.JointName,
                                   _ c: VNHumanBodyPoseObservation.JointName) -> CGFloat? {
        guard let pa = joints[a], let pb = joints[b], let pc = joints[c] else { return nil }
        let v1 = CGVector(dx: pa.x - pb.x, dy: pa.y - pb.y)
        let v2 = CGVector(dx: pc.x - pb.x, dy: pc.y - pb.y)
        let dot = v1.dx * v2.dx + v1.dy * v2.dy
        let mag = hypot(v1.dx, v1.dy) * hypot(v2.dx, v2.dy)
        guard mag > 0 else { return nil }
        return acos(max(-1, min(1, dot / mag))) * 180 / .pi
    }

    /// Knee-spread ÷ ankle-spread at the bottom pose — the knee-valgus proxy.
    private static func valgusRatio(from j: [VNHumanBodyPoseObservation.JointName: CGPoint]) -> CGFloat? {
        guard let lk = j[.leftKnee], let rk = j[.rightKnee],
              let la = j[.leftAnkle], let ra = j[.rightAnkle] else { return nil }
        let knee = abs(lk.x - rk.x), ankle = abs(la.x - ra.x)
        guard ankle > 0.001 else { return nil }
        return knee / ankle
    }
}

// MARK: - Camera preview (AVCaptureVideoPreviewLayer)

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.backgroundColor = .black
        view.configuredSession = session
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.configuredSession = session
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

        var configuredSession: AVCaptureSession? {
            didSet { attachSession() }
        }

        // Assigning the session to the preview layer BEFORE the view is in the
        // window hierarchy can leave the preview connection inactive — a black
        // screen even though the session is running. Re-attaching once the view
        // has a window (and on every session change) is the reliable fix.
        override func didMoveToWindow() {
            super.didMoveToWindow()
            attachSession()
        }

        private func attachSession() {
            guard window != nil, let session = configuredSession else { return }
            if videoPreviewLayer.session !== session {
                videoPreviewLayer.session = session
            }
            videoPreviewLayer.videoGravity = .resizeAspectFill
            // Pin the preview to portrait; the front-camera preview layer is
            // mirrored (selfie) by default, matching the pose overlay's coords.
            if let connection = videoPreviewLayer.connection,
               connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
        }
    }
}

// MARK: - Skeleton + framing overlay

private struct PoseOverlay: View {
    let joints: [VNHumanBodyPoseObservation.JointName: CGPoint]
    let framing: FramingState

    // Bones to connect, as joint-name pairs.
    private static let bones: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
        (.neck, .leftShoulder), (.neck, .rightShoulder),
        (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
        (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist),
        (.neck, .root),
        (.root, .leftHip), (.root, .rightHip),
        (.leftHip, .leftKnee), (.leftKnee, .leftAnkle),
        (.rightHip, .rightKnee), (.rightKnee, .rightAnkle)
    ]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                // Distance framing box.
                RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                    .inset(by: 4)
                    .stroke(framing.color, style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                    .padding(.horizontal, w * 0.10)
                    .padding(.vertical, h * 0.06)

                // Bones.
                Path { path in
                    for (a, b) in Self.bones {
                        guard let pa = joints[a], let pb = joints[b] else { continue }
                        path.move(to: CGPoint(x: pa.x * w, y: pa.y * h))
                        path.addLine(to: CGPoint(x: pb.x * w, y: pb.y * h))
                    }
                }
                .stroke(framing.color.opacity(0.9), lineWidth: 3)

                // Joints.
                ForEach(Array(joints.keys), id: \.self) { name in
                    if let p = joints[name] {
                        Circle()
                            .fill(framing.color)
                            .frame(width: 8, height: 8)
                            .position(x: p.x * w, y: p.y * h)
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .animation(.linear(duration: 0.08), value: framing)
    }
}

// MARK: - Screen

struct FormCheckView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var session: FormCheckSession
    @State private var summaryPayload: SummaryPayload?
    @State private var flashGrade: FormRepGrade?
    @State private var flashToken = 0

    /// Called with the rep count when the user submits the set, so the live
    /// workout can log the camera-counted reps.
    var onFinish: (Int) -> Void = { _ in }

    private struct SummaryPayload: Identifiable {
        let id = UUID()
        let summary: FormSetSummary
        let bestEver: Double?
        let movement: FormCheckMovement
        let exerciseName: String
        let metrics: [FormRepMetrics]
    }

    init(exerciseName: String = "Squat", movement: FormCheckMovement = .squat,
         onFinish: @escaping (Int) -> Void = { _ in }) {
        _session = State(initialValue: FormCheckSession(exerciseName: exerciseName, movement: movement))
        self.onFinish = onFinish
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch session.availability {
            case .authorized:
                liveView
            case .denied:
                messageState(
                    title: "Camera access needed",
                    detail: "Form Check needs the camera to see your movement. Enable it in Settings → Morphe → Camera. Video never leaves your phone."
                )
            case .unavailable:
                messageState(
                    title: "Needs a real device",
                    detail: "Form Check uses the front camera, which the Simulator doesn't have. Run Morphe on an iPhone to try it."
                )
            case .unknown:
                ProgressView().tint(MorpheTheme.accent)
            }
        }
        .task { session.configure() }
        .onDisappear { session.stop() }
        .sheet(item: $summaryPayload) { payload in
            FormSummarySheet(
                summary: payload.summary,
                bestEver: payload.bestEver,
                movement: payload.movement,
                exerciseName: payload.exerciseName,
                metrics: payload.metrics
            ) {
                let reps = payload.summary.reps
                summaryPayload = nil
                onFinish(reps)
                dismiss()
            }
        }
    }

    private var liveView: some View {
        ZStack {
            CameraPreview(session: session.session).ignoresSafeArea()
            PoseOverlay(joints: session.joints, framing: session.framing).ignoresSafeArea()

            VStack {
                header

                // Per-rep grade pop-up at the top — clear of the framing pill
                // and rep counter at the bottom.
                if let flashGrade {
                    Text(flashGrade.rawValue.uppercased())
                        .font(.system(size: 34, design: .monospaced).weight(.heavy))
                        .tracking(3)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24).padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                                .fill(flashGrade.color.opacity(0.92))
                        )
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                        .padding(.top, 10)
                }

                Spacer()
                footer
            }
            .padding(20)
        }
        .onChange(of: session.repCount) { _, _ in
            guard let grade = session.lastRepGrade else { return }
            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { flashGrade = grade }
            flashToken += 1
            let token = flashToken
            Task {
                try? await Task.sleep(for: .seconds(1.1))
                if token == flashToken {
                    withAnimation(.easeOut(duration: 0.3)) { flashGrade = nil }
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("FORM CHECK · BETA")
                    .font(MorpheTheme.microLabel(10)).tracking(1.6)
                    .foregroundStyle(MorpheTheme.accent)
                Text(session.exerciseName.uppercased())
                    .font(.system(size: 22, design: .monospaced).weight(.bold)).tracking(2)
                    .foregroundStyle(.white)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline).foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(RoundedRectangle(cornerRadius: MorpheTheme.radius).fill(.black.opacity(0.5)))
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 14) {
            // Framing status pill.
            Text(session.framing.label)
                .font(MorpheTheme.microLabel(12)).tracking(1.6)
                .foregroundStyle(.black)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: MorpheTheme.radius).fill(session.framing.color))

            VStack(spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("\(session.repCount)")
                        .font(.system(size: 56, design: .monospaced).weight(.bold))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                    Text("REPS")
                        .font(MorpheTheme.microLabel(12)).tracking(2)
                        .foregroundStyle(MorpheTheme.textSecondary)
                    Spacer()
                }

                HStack(spacing: 10) {
                    Button("Reset") { session.resetReps() }
                        .buttonStyle(SecondaryCTAButtonStyle())
                    Button("Finish & Review") {
                        let result = session.finishSet()
                        summaryPayload = SummaryPayload(
                            summary: result.summary,
                            bestEver: result.bestEverAngle,
                            movement: session.movement,
                            exerciseName: session.exerciseName,
                            metrics: session.repMetrics
                        )
                    }
                    .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                    .disabled(session.repCount == 0)
                    .opacity(session.repCount == 0 ? 0.5 : 1)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: MorpheTheme.radius).fill(.black.opacity(0.55)))

            Text("Morphe reads what the front camera can see — depth, body tracking, and tempo. It's a training aid, not a physical therapist.")
                .font(.caption2)
                .foregroundStyle(MorpheTheme.textMuted)
                .multilineTextAlignment(.center)
        }
    }

    private func messageState(title: String, detail: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "camera.metering.unknown")
                .font(.system(size: 40)).foregroundStyle(MorpheTheme.accent)
            Text(title).font(.title3.weight(.bold)).foregroundStyle(.white)
            Text(detail)
                .font(.subheadline).foregroundStyle(MorpheTheme.textSecondary)
                .multilineTextAlignment(.center)
            Button("Close") { dismiss() }
                .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                .padding(.top, 8)
        }
        .padding(28)
    }
}

// MARK: - Set review (post-set summary + honest cues)

private struct FormSummarySheet: View {
    let summary: FormSetSummary
    let bestEver: Double?
    var movement: FormCheckMovement = .squat
    var exerciseName: String = "Squat"
    var metrics: [FormRepMetrics] = []
    let onClose: () -> Void

    private var jointLabel: String { movement == .squat ? "knee" : "elbow" }

    #if DEBUG
    @State private var aiText: String?
    @State private var aiError: String?
    @State private var aiLoading = false
    @State private var keyDraft = ""
    @State private var hasKey = (DevAIKey.value?.isEmpty == false)
    #endif

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    SectionTitleView(title: "Set Review", subtitle: "What the front camera measured this set.")

                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                MetricPill(label: "Reps", value: "\(summary.reps)")
                                MetricPill(label: "Avg \(jointLabel)", value: summary.reps > 0 ? "\(Int(summary.avgMinKneeAngle))°" : "—")
                                MetricPill(label: "Deepest", value: summary.reps > 0 ? "\(Int(summary.bestMinKneeAngle))°" : "—")
                            }
                            Text("A smaller \(jointLabel) angle means a deeper rep — about 90° is a full range.")
                                .font(.caption2)
                                .foregroundStyle(MorpheTheme.textMuted)
                        }
                    }

                    if summary.cues.isEmpty {
                        GlassCard {
                            Text(summary.reps == 0
                                 ? "No full reps were counted. Make sure your whole body is inside the green frame, then try again."
                                 : "Nothing to flag — those reps looked clean.")
                                .font(.subheadline)
                                .foregroundStyle(MorpheTheme.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        ForEach(Array(summary.cues.enumerated()), id: \.offset) { _, cue in
                            GlassCard {
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: cue.tone == .good ? "checkmark.circle.fill" : "arrow.up.forward.circle.fill")
                                        .foregroundStyle(cue.tone == .good ? Color(red: 0.30, green: 0.85, blue: 0.45) : MorpheTheme.accent)
                                    Text(cue.message)
                                        .font(.subheadline)
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    }

                    #if DEBUG
                    aiReviewSection
                    #endif

                    if let best = bestEver, best > 0 {
                        Text("Your deepest \(movement == .squat ? "squat" : "push-up") on record: \(Int(best))° \(jointLabel) bend.")
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textSecondary)
                    }

                    Text("These are what the camera could see — a helpful signal, not a medical assessment. If something hurts, stop.")
                        .font(.caption2)
                        .foregroundStyle(MorpheTheme.textMuted)
                }
                .padding(20)
            }
            .background(PremiumBackground())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { onClose() }.foregroundStyle(.white)
                }
            }
        }
    }

    #if DEBUG
    @ViewBuilder private var aiReviewSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("AI COACH · DEV")
                    .font(MorpheTheme.microLabel(10)).tracking(1.4)
                    .foregroundStyle(MorpheTheme.accent)

                if !hasKey {
                    Text("Paste an Anthropic API key to try AI coaching on this set. Dev builds only — stored on this device, never shipped.")
                        .font(.caption).foregroundStyle(MorpheTheme.textSecondary)
                    SecureField("sk-ant-...", text: $keyDraft)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    Button("Save key") {
                        DevAIKey.value = keyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                        hasKey = (DevAIKey.value?.isEmpty == false)
                        keyDraft = ""
                    }
                    .buttonStyle(SecondaryCTAButtonStyle())
                } else if let aiText {
                    Text(aiText)
                        .font(.subheadline).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button("Re-run") { Task { await runAIReview() } }
                        .buttonStyle(SecondaryCTAButtonStyle())
                } else {
                    if let aiError {
                        Text(aiError)
                            .font(.caption).foregroundStyle(Color(red: 0.92, green: 0.40, blue: 0.40))
                    }
                    Button(aiLoading ? "Reviewing…" : "Get AI coaching") {
                        Task { await runAIReview() }
                    }
                    .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                    .disabled(aiLoading || summary.reps == 0)
                }
            }
        }
    }

    @MainActor private func runAIReview() async {
        aiLoading = true
        aiError = nil
        defer { aiLoading = false }
        do {
            aiText = try await FormAIReviewer().review(
                exerciseName: exerciseName, movement: movement, metrics: metrics)
        } catch {
            aiError = (error as? FormAIReviewer.APIError)?.message ?? error.localizedDescription
        }
    }
    #endif
}

#if DEBUG
// MARK: - Dev-only Claude form review
//
// GATED TO DEBUG BUILDS ONLY — never compiled into a release/TestFlight/App
// Store build, so the app can never ship an API key or call Anthropic
// directly. This is a temporary way to feel the AI coaching before the
// Firebase Cloud Function proxy exists (the proxy is where the key lives for
// real). The key is entered at runtime and stored on-device.

enum DevAIKey {
    private static let storageKey = "morphe.dev.anthropicKey"
    static var value: String? {
        get { UserDefaults.standard.string(forKey: storageKey) }
        set { UserDefaults.standard.set(newValue, forKey: storageKey) }
    }
}

struct FormAIReviewer {
    struct APIError: Error { let message: String }

    /// Sends the MEASURED rep data (angles/tempo — never video) to Claude and
    /// returns a short coaching note. Raw HTTPS: Swift has no official
    /// Anthropic SDK.
    func review(exerciseName: String, movement: FormCheckMovement, metrics: [FormRepMetrics]) async throws -> String {
        guard let apiKey = DevAIKey.value, !apiKey.isEmpty else {
            throw APIError(message: "No API key set.")
        }
        guard !metrics.isEmpty else {
            throw APIError(message: "No reps to review.")
        }

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "model": "claude-opus-4-8",
            "max_tokens": 320,
            "system": Self.system,
            "messages": [["role": "user", "content": Self.prompt(exerciseName: exerciseName, movement: movement, metrics: metrics)]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError(message: "No response from the API.") }
        guard http.statusCode == 200 else {
            let detail = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
                .flatMap { ($0?["error"] as? [String: Any])?["message"] as? String }
            throw APIError(message: "API \(http.statusCode): \(detail ?? "request failed")")
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]] else {
            throw APIError(message: "Couldn't read the response.")
        }
        let text = content.compactMap { $0["text"] as? String }.joined().trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? "No coaching came back — try again." : text
    }

    private static let system = """
    You are an experienced, encouraging strength coach reviewing ONE set an athlete just finished. It was measured by a phone's front camera — you have joint angles per rep, not video. Give 2–4 short sentences of specific coaching grounded ONLY in the numbers provided (depth/range of motion, tempo, consistency across reps, and knee tracking for squats). Never diagnose injuries or pain. If the set looks clean, say so and give one thing to keep doing. Plain conversational language, no bullet lists, no preamble.
    """

    private static func prompt(exerciseName: String, movement: FormCheckMovement, metrics: [FormRepMetrics]) -> String {
        var lines: [String] = [
            "Exercise: \(exerciseName)",
            "Pattern: \(movement == .squat ? "squat — the angle is the knee (hip-knee-ankle)" : "push-up — the angle is the elbow (shoulder-elbow-wrist)")",
            "Reps counted: \(metrics.count)"
        ]
        for (i, m) in metrics.enumerated() {
            var parts = ["depth \(Int(m.minKneeAngle))°", "descent \(String(format: "%.1f", m.descentSeconds))s"]
            if movement == .squat, let v = m.valgusRatio {
                parts.append("knee/ankle spread \(String(format: "%.2f", v))")
            }
            lines.append("Rep \(i + 1): " + parts.joined(separator: ", "))
        }
        lines.append("")
        lines.append("Reference: a smaller angle = a deeper rep; ~90° is full range. For squats, knee/ankle spread below ~0.85 suggests the knees caving inward (but a single front camera reads this loosely).")
        return lines.joined(separator: "\n")
    }
}
#endif
