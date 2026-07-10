import SwiftUI
import AVFoundation
import CoreImage.CIFilterBuiltins

// MARK: - QR connect (both roles)
//
// "My Code" renders this account's Morphe connect code; "Scan" reads another
// user's code with the camera and records the connection on this account.
// Honest boundary: a scan stores the connection HERE (name, handle, role) —
// mutual rosters and messaging arrive when the backend links both accounts.

struct QRConnectSheet: View {
    @Environment(MorpheAppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    enum Mode: String, CaseIterable, Identifiable {
        case show = "My Code"
        case scan = "Scan"
        var id: String { rawValue }
    }

    @State var mode: Mode = .show
    @State private var lastScanned: ScannedConnection?

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("Mode", selection: $mode) {
                        ForEach(Mode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    if mode == .show {
                        myCodeCard
                    } else {
                        scanCard
                    }

                    if !store.scannedConnections.isEmpty {
                        connectionsCard
                    }
                }
                .padding(20)
            }
            .background(PremiumBackground())
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Connect").font(.headline).foregroundStyle(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(.white)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var myCodeCard: some View {
        GlassCard {
            VStack(spacing: 14) {
                Text(store.selectedRole == .coach ? store.coachProfile.name : store.clientProfile.name)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)

                if let image = QRCodeRenderer.image(for: store.qrConnectPayload) {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 240)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                                .fill(.white)
                        )
                } else {
                    Text("Couldn't render your code.")
                        .foregroundStyle(MorpheTheme.textSecondary)
                }

                let handle = store.selectedRole == .coach ? store.coachProfile.username : store.profileShowcase.username
                if !handle.isEmpty {
                    Text("@\(handle)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MorpheTheme.textSecondary)
                }

                Text("Have a coach or training partner scan this from their Morphe app.")
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textMuted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var scanCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                QRScannerView { payload in
                    // First valid Morphe code wins; others are ignored.
                    if let connection = store.recordScannedConnection(from: payload) {
                        lastScanned = connection
                        mode = .show
                    }
                }
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous))

                Text("Point the camera at a Morphe connect code.")
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textMuted)
            }
        }
    }

    private var connectionsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Connections")
                    .font(.headline)
                    .foregroundStyle(.white)

                ForEach(store.scannedConnections) { connection in
                    HStack(spacing: 10) {
                        Image(systemName: connection.role == "coach" ? "figure.wave" : "figure.run")
                            .foregroundStyle(MorpheTheme.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(connection.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Text(connection.handle.isEmpty ? connection.role.capitalized : "@\(connection.handle) · \(connection.role.capitalized)")
                                .font(.caption)
                                .foregroundStyle(MorpheTheme.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 2)
                }

                Text("Saved on your account. Shared rosters and messaging unlock as account linking rolls out.")
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textMuted)
            }
        }
    }
}

// MARK: - QR rendering

enum QRCodeRenderer {
    static func image(for payload: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        // Scale up so the code renders crisp instead of blurry.
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - QR scanning

/// Camera-backed QR scanner. On hardware without a camera (the simulator)
/// it shows an honest placeholder instead of a black box.
struct QRScannerView: View {
    let onScan: (String) -> Void

    var body: some View {
        if AVCaptureDevice.default(for: .video) == nil {
            VStack(spacing: 10) {
                Image(systemName: "camera.on.rectangle")
                    .font(.largeTitle)
                    .foregroundStyle(MorpheTheme.textMuted)
                Text("No camera available here.\nScanning works on your iPhone.")
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(MorpheTheme.panelStrong)
        } else {
            QRCameraRepresentable(onScan: onScan)
        }
    }
}

private struct QRCameraRepresentable: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    func makeUIViewController(context: Context) -> QRScannerController {
        let controller = QRScannerController()
        controller.onScan = onScan
        return controller
    }

    func updateUIViewController(_ controller: QRScannerController, context: Context) {}
}

final class QRScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onScan: ((String) -> Void)?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    /// Debounce: the camera reports the same code many times per second.
    private var lastPayload: String?
    private var lastScanAt = Date.distantPast

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)
        previewLayer = preview
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let session = session
        DispatchQueue.global(qos: .userInitiated).async {
            if !session.isRunning { session.startRunning() }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        let session = session
        DispatchQueue.global(qos: .userInitiated).async {
            if session.isRunning { session.stopRunning() }
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              object.type == .qr,
              let payload = object.stringValue else { return }
        // Ignore repeat reads of the same code within a couple of seconds.
        if payload == lastPayload, Date().timeIntervalSince(lastScanAt) < 2 { return }
        lastPayload = payload
        lastScanAt = Date()
        onScan?(payload)
    }
}
