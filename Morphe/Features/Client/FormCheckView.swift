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

    // Rep-counting state machine (knee-angle based for the squat).
    private var repPhase: RepPhase = .up
    private enum RepPhase { case up, down }

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
    }

    // MARK: Frame processing

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

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
        let rep = updateReps(with: mapped, framing: framing)

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.joints = mapped
            self.framing = framing
            if rep { self.repCount += 1; Haptics.impact(.light) }
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
                            framing: FramingState) -> Bool {
        guard framing.isTrackable, let angle = kneeAngle(from: joints) else { return false }

        // Hysteresis: descend past 100° to arm a rep, rise past 155° to bank it.
        switch repPhase {
        case .up where angle < 100:
            repPhase = .down
        case .down where angle > 155:
            repPhase = .up
            return true
        default:
            break
        }
        return false
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
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
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

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(session.repCount)")
                    .font(.system(size: 56, design: .monospaced).weight(.bold))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                Text("REPS")
                    .font(MorpheTheme.microLabel(12)).tracking(2)
                    .foregroundStyle(MorpheTheme.textSecondary)
                Spacer()
                Button("Reset") { session.resetReps() }
                    .buttonStyle(SecondaryCTAButtonStyle())
                    .frame(width: 96)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: MorpheTheme.radius).fill(.black.opacity(0.55)))

            Text("Form cues are coming next — for now Morphe counts your reps and helps you frame up. This is a training aid, not a physical therapist.")
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
