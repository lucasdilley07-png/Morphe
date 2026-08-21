import AVFoundation
import Photos
import SwiftUI

// MARK: - Capture camera (the Network posting door)
//
// Snapchat-shaped: open on the viewfinder, tap to shoot a photo, switch to
// video and record a clip. What happens NEXT is where Morphe stays honest
// about its backend:
//   - Photos post to the feed for real (small JPEG inside the post doc,
//     capped by the rules at ~64KB — Spark has no file storage).
//   - Video clips can't upload anywhere yet, and the UI says so: the review
//     screen offers "Save to Photos" and names the unlock condition instead
//     of a Post button that silently drops the file.
// Form Check stays one tap away — it's the same hardware pointed at a
// different job, and burying it under the new camera would lose a feature.

@Observable
final class CaptureCameraController: NSObject {
    enum Mode: String, CaseIterable {
        case photo = "PHOTO"
        case video = "VIDEO"
    }

    let session = AVCaptureSession()
    var mode: Mode = .photo
    var isRecording = false
    var isAuthorized = false
    /// Set when a shot lands: the sized-down JPEG ready for the composer.
    var capturedJPEG: Data?
    /// Set when a recording finishes: the temp clip URL for review.
    var finishedClipURL: URL?
    var recordingSeconds = 0

    private let photoOutput = AVCapturePhotoOutput()
    private let movieOutput = AVCaptureMovieFileOutput()
    private var position: AVCaptureDevice.Position = .back
    private let sessionQueue = DispatchQueue(label: "morphe.capture.session")
    private var recordingTimer: Timer?

    /// Hard stop mirrored in the UI — long enough for a set clip, short
    /// enough that the file stays saveable on any phone.
    static let maxClipSeconds = 60

    func configure() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
            buildSessionAndStart()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                    if granted { self?.buildSessionAndStart() }
                }
            }
        default:
            isAuthorized = false
        }
    }

    private func buildSessionAndStart() {
        sessionQueue.async { [self] in
            session.beginConfiguration()
            session.sessionPreset = .high
            for input in session.inputs { session.removeInput(input) }
            if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
               let input = try? AVCaptureDeviceInput(device: device),
               session.canAddInput(input) {
                session.addInput(input)
            }
            // Audio only in VIDEO mode (launch audit P1-8): a mic permission
            // prompt on a photo camera reads as spyware — the ask waits
            // until the user actually switches to clips.
            if mode == .video,
               let mic = AVCaptureDevice.default(for: .audio),
               let micInput = try? AVCaptureDeviceInput(device: mic),
               session.canAddInput(micInput) {
                // One mic owner at a time (audit 12, P0-3).
                HeyMorpheEngine.shared.pauseForExternalAudio()
                session.addInput(micInput)
            }
            if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
            if session.canAddOutput(movieOutput) { session.addOutput(movieOutput) }
            session.commitConfiguration()
            if !session.isRunning { session.startRunning() }
        }
    }

    func flipCamera() {
        position = position == .back ? .front : .back
        buildSessionAndStart()
    }

    /// Mode changes rebuild the session so the mic input attaches only for
    /// video (and its permission prompt fires only then).
    func setMode(_ newMode: Mode) {
        guard newMode != mode else { return }
        mode = newMode
        buildSessionAndStart()
    }

    func stop() {
        recordingTimer?.invalidate()
        sessionQueue.async { [self] in
            if movieOutput.isRecording { movieOutput.stopRecording() }
            if session.isRunning { session.stopRunning() }
            HeyMorpheEngine.shared.resumeAfterExternalAudio()
        }
    }

    func shootPhoto() {
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func toggleRecording() {
        if movieOutput.isRecording {
            movieOutput.stopRecording()
            return
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("morphe-capture-\(UUID().uuidString).mov")
        movieOutput.startRecording(to: url, recordingDelegate: self)
        isRecording = true
        recordingSeconds = 0
        recordingTimer?.invalidate()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            recordingSeconds += 1
            if recordingSeconds >= Self.maxClipSeconds, movieOutput.isRecording {
                movieOutput.stopRecording()
            }
        }
    }

    func clearCaptures() {
        capturedJPEG = nil
        if let url = finishedClipURL {
            try? FileManager.default.removeItem(at: url)
        }
        finishedClipURL = nil
    }

    /// Feed-sized JPEG: longest edge 720px, quality stepped down until the
    /// base64 form fits the rules cap (90k chars). Returns nil only when
    /// even the floor quality can't fit — pathological, but never posted
    /// corrupt.
    static func feedJPEG(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let maxEdge: CGFloat = 720
        let scale = min(1, maxEdge / max(image.size.width, image.size.height))
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target)
        let sized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        for quality in stride(from: 0.6, through: 0.2, by: -0.1) {
            if let jpeg = sized.jpegData(compressionQuality: quality),
               jpeg.base64EncodedString().count <= 90_000 {
                return jpeg
            }
        }
        return nil
    }
}

extension CaptureCameraController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        guard error == nil, let data = photo.fileDataRepresentation() else { return }
        DispatchQueue.main.async { [weak self] in
            self?.capturedJPEG = CaptureCameraController.feedJPEG(from: data)
            Haptics.impact(.medium)
        }
    }
}

extension CaptureCameraController: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?) {
        DispatchQueue.main.async { [weak self] in
            self?.isRecording = false
            self?.recordingTimer?.invalidate()
            if error == nil {
                self?.finishedClipURL = outputFileURL
                Haptics.impact(.medium)
            }
        }
    }
}

/// The always-live preview layer, UIKit-hosted like Form Check's.
struct CaptureCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    final class PreviewHost: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    func makeUIView(context: Context) -> PreviewHost {
        let view = PreviewHost()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewHost, context: Context) {}
}

struct CaptureView: View {
    @Environment(MorpheAppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var camera = CaptureCameraController()
    @State private var showFormCheck = false
    @State private var caption = ""
    @State private var isPosting = false
    @State private var clipSaveState: ClipSaveState = .idle
    @FocusState private var captionFocused: Bool

    enum ClipSaveState { case idle, saving, saved, failed }

    var body: some View {
        ZStack {
            MorpheTheme.ink.ignoresSafeArea()

            if showFormCheck {
                // The training-aid camera, unchanged — same door it always
                // was, now reached from inside capture. Exercise-scoped when
                // a session is live, same as the old header door.
                if let exercise = store.activeWorkoutExercise, store.isWorkoutSessionActive {
                    FormCheckView(
                        exerciseName: exercise.name,
                        movement: .infer(exerciseName: exercise.name, muscleGroup: exercise.muscleGroup)
                    )
                    .environment(store)
                } else {
                    FormCheckView()
                        .environment(store)
                }
            } else if let jpeg = camera.capturedJPEG {
                photoComposer(jpeg: jpeg)
            } else if let clipURL = camera.finishedClipURL {
                clipReview(url: clipURL)
            } else {
                viewfinder
            }
        }
        .onAppear { camera.configure() }
        .onDisappear {
            camera.stop()
            // Abandoned recordings must not leak 60s of 1080p into tmp.
            camera.clearCaptures()
        }
    }

    // MARK: Viewfinder

    private var viewfinder: some View {
        ZStack {
            if camera.isAuthorized {
                CaptureCameraPreview(session: camera.session)
                    .ignoresSafeArea()
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "camera.fill")
                        .font(.largeTitle)
                        .foregroundStyle(MorpheTheme.textMuted)
                    Text("Camera access is off")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Enable the camera in Settings to shoot photos and clips.")
                        .font(.subheadline)
                        .foregroundStyle(MorpheTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(40)
            }

            VStack {
                HStack {
                    Button {
                        camera.stop()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(.black.opacity(0.45)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close camera")

                    Spacer()

                    if camera.isRecording {
                        Text(String(format: "0:%02d", camera.recordingSeconds))
                            .font(MorpheTheme.microLabel(12))
                            .tracking(1.2)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .frame(height: 32)
                            .background(Capsule().fill(.red.opacity(0.8)))
                    }

                    Spacer()

                    Button {
                        // Two AVCaptureSessions can't share the hardware —
                        // hand it off before Form Check builds its own.
                        camera.stop()
                        showFormCheck = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "figure.strengthtraining.traditional")
                                .font(.caption.weight(.bold))
                            Text("FORM")
                                .font(MorpheTheme.microLabel(10))
                                .tracking(1.2)
                        }
                        .foregroundStyle(MorpheTheme.accent)
                        .padding(.horizontal, 12)
                        .frame(height: 44)
                        .background(Capsule().fill(.black.opacity(0.45)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Switch to Form Check")
                }
                .padding(.horizontal, 16)

                Spacer()

                // Mode + shutter + flip — the Snapchat bottom row.
                VStack(spacing: 14) {
                    HStack(spacing: 10) {
                        ForEach(CaptureCameraController.Mode.allCases, id: \.self) { mode in
                            Button(mode.rawValue) {
                                guard !camera.isRecording else { return }
                                camera.setMode(mode)
                            }
                            .font(MorpheTheme.microLabel(11))
                            .tracking(1.4)
                            .foregroundStyle(camera.mode == mode ? MorpheTheme.accent : MorpheTheme.textSecondary)
                            .frame(minWidth: 60, minHeight: 32)
                        }
                    }

                    HStack {
                        Color.clear.frame(width: 54, height: 54)

                        Spacer()

                        Button {
                            if camera.mode == .photo {
                                camera.shootPhoto()
                            } else {
                                camera.toggleRecording()
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .stroke(.white, lineWidth: 4)
                                    .frame(width: 74, height: 74)
                                if camera.isRecording {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(.red)
                                        .frame(width: 30, height: 30)
                                } else {
                                    Circle()
                                        .fill(camera.mode == .video ? .red : .white)
                                        .frame(width: 60, height: 60)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(
                            camera.mode == .photo
                                ? "Take photo"
                                : (camera.isRecording ? "Stop recording" : "Start recording")
                        )

                        Spacer()

                        Button {
                            camera.flipCamera()
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath.camera")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(width: 54, height: 54)
                                .background(Circle().fill(.black.opacity(0.45)))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Flip camera")
                        .disabled(camera.isRecording)
                    }
                    .padding(.horizontal, 28)
                }
                .padding(.bottom, 24)
            }
        }
    }

    // MARK: Photo composer

    private func photoComposer(jpeg: Data) -> some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                if let image = UIImage(data: jpeg) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous))
                        .padding(16)
                }
                Button {
                    camera.clearCaptures()
                    caption = ""
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(.black.opacity(0.45)))
                }
                .buttonStyle(.plain)
                .padding(24)
                .accessibilityLabel("Retake")
            }
            .frame(maxHeight: .infinity)
            .onTapGesture { captionFocused = false }

            VStack(spacing: 10) {
                TextField("Add a caption…", text: $caption, axis: .vertical)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .lineLimit(1...3)
                    .focused($captionFocused)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                            .fill(MorpheTheme.panelStrong)
                    )

                Button {
                    guard !isPosting else { return }
                    isPosting = true
                    // Optimistic close (speed audit S2-7): the camera
                    // dismisses NOW; publish continues in the background and
                    // the store toasts success or failure either way. The
                    // base64 encode runs off the main actor (S2-8).
                    let capturedCaption = caption
                    camera.stop()
                    dismiss()
                    Task {
                        let encoded = await Task.detached(priority: .userInitiated) {
                            jpeg.base64EncodedString()
                        }.value
                        _ = await store.publishPhotoPost(
                            caption: capturedCaption,
                            imageB64: encoded
                        )
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isPosting {
                            ProgressView().tint(.black)
                        } else {
                            Image(systemName: "paperplane.fill")
                                .font(.subheadline.weight(.bold))
                        }
                        Text(isPosting ? "POSTING…" : "POST TO FEED")
                            .font(MorpheTheme.microLabel(12))
                            .tracking(1.6)
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(
                        RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                            .fill(MorpheTheme.brandYellow)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isPosting)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    // MARK: Clip review (honest: no fake video posting)

    private func clipReview(url: URL) -> some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                ClipLoopPlayer(url: url)
                    .clipShape(RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous))
                    .padding(16)
                Button {
                    camera.clearCaptures()
                    clipSaveState = .idle
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(.black.opacity(0.45)))
                }
                .buttonStyle(.plain)
                .padding(24)
                .accessibilityLabel("Retake")
            }
            .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 10) {
                // The honest line — a Post button here would drop the file
                // on the floor. Named unlock, not vague "coming soon".
                Text("Video posts unlock when Morphe gets cloud file storage. Until then, save the clip and share it anywhere.")
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    saveClipToPhotos(url: url)
                } label: {
                    HStack(spacing: 8) {
                        switch clipSaveState {
                        case .saving:
                            ProgressView().tint(.black)
                        case .saved:
                            Image(systemName: "checkmark")
                                .font(.subheadline.weight(.bold))
                        default:
                            Image(systemName: "square.and.arrow.down")
                                .font(.subheadline.weight(.bold))
                        }
                        Text(clipSaveLabel)
                            .font(MorpheTheme.microLabel(12))
                            .tracking(1.6)
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(
                        RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                            .fill(MorpheTheme.brandYellow)
                    )
                }
                .buttonStyle(.plain)
                .disabled(clipSaveState == .saving || clipSaveState == .saved)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    private var clipSaveLabel: String {
        switch clipSaveState {
        case .idle: return "SAVE TO PHOTOS"
        case .saving: return "SAVING…"
        case .saved: return "SAVED"
        case .failed: return "COULDN'T SAVE — TRY AGAIN"
        }
    }

    private func saveClipToPhotos(url: URL) {
        clipSaveState = .saving
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async { clipSaveState = .failed }
                return
            }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            } completionHandler: { success, _ in
                DispatchQueue.main.async {
                    clipSaveState = success ? .saved : .failed
                    if success { Haptics.impact(.light) }
                }
            }
        }
    }
}

/// Muted looping preview for the just-recorded clip.
private struct ClipLoopPlayer: View {
    let url: URL
    @State private var player: AVPlayer?

    var body: some View {
        VideoPlayerHost(player: player)
            .onAppear {
                let item = AVPlayerItem(url: url)
                let loop = AVPlayer(playerItem: item)
                loop.isMuted = true
                loop.play()
                NotificationCenter.default.addObserver(
                    forName: .AVPlayerItemDidPlayToEndTime,
                    object: item,
                    queue: .main
                ) { _ in
                    loop.seek(to: .zero)
                    loop.play()
                }
                player = loop
            }
            .onDisappear { player?.pause() }
    }
}

private struct VideoPlayerHost: UIViewRepresentable {
    let player: AVPlayer?

    final class PlayerHost: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }

    func makeUIView(context: Context) -> PlayerHost {
        let view = PlayerHost()
        view.playerLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PlayerHost, context: Context) {
        uiView.playerLayer.player = player
    }
}
