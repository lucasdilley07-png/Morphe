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

// MARK: Exercise model

enum FormCheckExercise: String, CaseIterable, Identifiable {
    case squat = "Squat"

    var id: String { rawValue }

    var setupHint: String {
        switch self {
        case .squat:
            return "Stand facing the camera with your whole body in frame. Squat at a steady, controlled tempo."
        }
    }
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

    static func analyze(_ metrics: [FormRepMetrics]) -> FormSetSummary {
        guard !metrics.isEmpty else {
            return FormSetSummary(reps: 0, avgMinKneeAngle: 0, bestMinKneeAngle: 0, cues: [])
        }
        let n = metrics.count
        let angles = metrics.map(\.minKneeAngle)
        let avg = angles.reduce(0, +) / CGFloat(n)
        let best = angles.min() ?? 0

        var cues: [FormCue] = []

        // Knees first — it's the injury-relevant cue, so it leads.
        let valgusValues = metrics.compactMap(\.valgusRatio)
        let caved = valgusValues.filter { $0 < valgusRatio }.count
        if valgusValues.count >= 2, Double(caved) / Double(valgusValues.count) > 0.3 {
            cues.append(FormCue(category: .knees, tone: .suggestion,
                message: "Push your knees out — they drifted inward on \(caved) rep\(caved == 1 ? "" : "s"), often as you tire."))
        }

        // Depth.
        let shallow = angles.filter { $0 > shallowAngle }.count
        if Double(shallow) / Double(n) > 0.4 {
            cues.append(FormCue(category: .depth, tone: .suggestion,
                message: "Try sitting a little lower — \(shallow) of \(n) rep\(n == 1 ? "" : "s") stopped above parallel."))
        } else {
            cues.append(FormCue(category: .depth, tone: .good,
                message: "Good depth — you're getting to about parallel."))
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

    /// One-line feedback for the rep that just finished (shown live).
    static func liveCue(for m: FormRepMetrics, repNumber: Int) -> String {
        if let v = m.valgusRatio, v < valgusRatio { return "Rep \(repNumber) · knees caved in" }
        if m.minKneeAngle > shallowAngle { return "Rep \(repNumber) · a little above parallel" }
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

    let exercise: FormCheckExercise
    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "com.morpheapp.formcheck.session")
    private let videoQueue = DispatchQueue(label: "com.morpheapp.formcheck.video")
    private let poseRequest = VNDetectHumanBodyPoseRequest()
    private var isConfigured = false

    // Per-rep feedback (Phase 2).
    private(set) var repMetrics: [FormRepMetrics] = []
    private(set) var liveCue: String?

    // Rep-counting + metric-capture state machine (knee-angle based, squat).
    private var repPhase: RepPhase = .up
    private enum RepPhase { case up, down }
    private var descentStartT: Double?
    private var minAngleThisRep: CGFloat = .greatestFiniteMagnitude
    private var bottomT: Double = 0
    private var bottomPose: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
    private let history = FormCheckFilePersistence()

    init(exercise: FormCheckExercise) {
        self.exercise = exercise
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
        repMetrics = []
        liveCue = nil
    }

    /// Ends the set, analyzes it, persists the result, and returns the summary
    /// plus the all-time best depth angle for the review screen.
    func finishSet() -> (summary: FormSetSummary, bestEverAngle: Double?) {
        stop()
        let summary = FormAnalyzer.analyze(repMetrics)
        if summary.reps > 0 {
            history.append(FormCheckResult(
                date: Date().timeIntervalSince1970,
                exercise: exercise.rawValue,
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
        var mapped: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
        for (name, point) in points where point.confidence > 0.3 {
            mapped[name] = CGPoint(x: 1 - point.location.x, y: 1 - point.location.y)
        }

        let framing = Self.framingState(for: mapped)
        let newRep = updateReps(with: mapped, framing: framing, time: frameTime)

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.joints = mapped
            self.framing = framing
            if let metrics = newRep {
                self.repMetrics.append(metrics)
                self.repCount += 1
                self.liveCue = FormAnalyzer.liveCue(for: metrics, repNumber: self.repCount)
                Haptics.impact(.light)
            }
        }
    }

    // MARK: Framing

    private static func framingState(for joints: [VNHumanBodyPoseObservation.JointName: CGPoint]) -> FramingState {
        // Need head-ish and feet-ish anchors to judge distance.
        let ys = joints.values.map(\.y)
        guard joints.count >= 6, let top = ys.min(), let bottom = ys.max() else { return .noPerson }
        let bodyHeight = bottom - top          // fraction of frame height
        switch bodyHeight {
        case 0.92...:      return .tooClose
        case 0.60..<0.92:  return .good
        default:           return .tooFar
        }
    }

    // MARK: Reps (squat: knee-angle state machine)

    private func updateReps(with joints: [VNHumanBodyPoseObservation.JointName: CGPoint],
                            framing: FramingState, time t: Double) -> FormRepMetrics? {
        guard framing.isTrackable, let angle = kneeAngle(from: joints) else { return nil }

        switch repPhase {
        case .up:
            if angle > 155 {
                // Standing, or an aborted partial — reset the rep accumulator.
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
                    valgusRatio: Self.valgusRatio(from: bottomPose),
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

    /// Knee-spread ÷ ankle-spread at the bottom pose — the knee-valgus proxy.
    private static func valgusRatio(from j: [VNHumanBodyPoseObservation.JointName: CGPoint]) -> CGFloat? {
        guard let lk = j[.leftKnee], let rk = j[.rightKnee],
              let la = j[.leftAnkle], let ra = j[.rightAnkle] else { return nil }
        let knee = abs(lk.x - rk.x), ankle = abs(la.x - ra.x)
        guard ankle > 0.001 else { return nil }
        return knee / ankle
    }

    /// Interior knee angle (hip–knee–ankle), preferring whichever leg is more
    /// confidently visible.
    private func kneeAngle(from joints: [VNHumanBodyPoseObservation.JointName: CGPoint]) -> CGFloat? {
        func angle(_ hip: VNHumanBodyPoseObservation.JointName,
                   _ knee: VNHumanBodyPoseObservation.JointName,
                   _ ankle: VNHumanBodyPoseObservation.JointName) -> CGFloat? {
            guard let h = joints[hip], let k = joints[knee], let a = joints[ankle] else { return nil }
            let v1 = CGVector(dx: h.x - k.x, dy: h.y - k.y)
            let v2 = CGVector(dx: a.x - k.x, dy: a.y - k.y)
            let dot = v1.dx * v2.dx + v1.dy * v2.dy
            let mag = hypot(v1.dx, v1.dy) * hypot(v2.dx, v2.dy)
            guard mag > 0 else { return nil }
            return acos(max(-1, min(1, dot / mag))) * 180 / .pi
        }
        return angle(.leftHip, .leftKnee, .leftAnkle) ?? angle(.rightHip, .rightKnee, .rightAnkle)
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

    private struct SummaryPayload: Identifiable {
        let id = UUID()
        let summary: FormSetSummary
        let bestEver: Double?
    }

    init(exercise: FormCheckExercise = .squat) {
        _session = State(initialValue: FormCheckSession(exercise: exercise))
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
            FormSummarySheet(summary: payload.summary, bestEver: payload.bestEver) {
                summaryPayload = nil
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
                Spacer()
                footer
            }
            .padding(20)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("FORM CHECK · BETA")
                    .font(MorpheTheme.microLabel(10)).tracking(1.6)
                    .foregroundStyle(MorpheTheme.accent)
                Text(session.exercise.rawValue.uppercased())
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

                if let cue = session.liveCue {
                    Text(cue.uppercased())
                        .font(MorpheTheme.microLabel(11)).tracking(1.2)
                        .foregroundStyle(MorpheTheme.accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.opacity)
                }

                HStack(spacing: 10) {
                    Button("Reset") { session.resetReps() }
                        .buttonStyle(SecondaryCTAButtonStyle())
                    Button("Finish & Review") {
                        let result = session.finishSet()
                        summaryPayload = SummaryPayload(summary: result.summary, bestEver: result.bestEverAngle)
                    }
                    .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                    .disabled(session.repCount == 0)
                    .opacity(session.repCount == 0 ? 0.5 : 1)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: MorpheTheme.radius).fill(.black.opacity(0.55)))
            .animation(.easeInOut(duration: 0.2), value: session.liveCue)

            Text("Morphe reads what the front camera can see — depth, knee tracking, and tempo. It's a training aid, not a physical therapist.")
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
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    SectionTitleView(title: "Set Review", subtitle: "What the front camera measured this set.")

                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                MetricPill(label: "Reps", value: "\(summary.reps)")
                                MetricPill(label: "Avg knee", value: summary.reps > 0 ? "\(Int(summary.avgMinKneeAngle))°" : "—")
                                MetricPill(label: "Deepest", value: summary.reps > 0 ? "\(Int(summary.bestMinKneeAngle))°" : "—")
                            }
                            Text("About 90° is roughly parallel — a smaller angle means a deeper squat.")
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

                    if let best = bestEver, best > 0 {
                        Text("Your deepest squat on record: \(Int(best))° knee bend.")
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
}
