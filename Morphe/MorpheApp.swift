import Combine
import SwiftUI
import FirebaseCore
import FirebaseAppCheck

/// Human-traffic-only (Lucas 2026-10-10): every Firestore request carries
/// an App Check token proving it came from the genuine Morphe app on a
/// real Apple device (App Attest; DeviceCheck on older iOS). A script with
/// a stolen login has no token. Enforcement is switched on in the Firebase
/// console (App Check → Firestore → Enforce) once tokens are flowing;
/// until then the SDK only reports.
///
/// GATED ON THE $99 PROGRAM: App Attest needs the
/// `com.apple.developer.devicecheck.appattest-environment` entitlement,
/// which a personal team cannot sign (Xcode refuses the profile). After
/// enrolment: add that key (value `production`) to Morphe.entitlements,
/// upload the DeviceCheck key in Firebase → App Check, then enforce.
final class MorpheAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        if #available(iOS 14.0, *) {
            return AppAttestProvider(app: app)
        }
        return DeviceCheckProvider(app: app)
    }
}

@main
struct MorpheApp: App {
    @State private var store: MorpheAppStore
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Firebase must be configured before anything touches Auth/Firestore —
        // assigning the store explicitly here (instead of a property default)
        // guarantees configure() runs first. The App Check factory goes in
        // BEFORE configure (the SDK reads it there); debug builds use the
        // debug provider (the simulator can't attest) — its token prints to
        // the console and is registered in Firebase for test devices.
        #if DEBUG
        AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
        #else
        AppCheck.setAppCheckProviderFactory(MorpheAppCheckProviderFactory())
        #endif
        FirebaseApp.configure()
        let auth = FirebaseAuthService()
        let store = MorpheAppStore(
            authService: auth,
            cloudBackup: FirebaseCloudBackup(),
            partyService: FirebasePartyService(),
            managedClientService: FirebaseManagedClientService(),
            usernameDirectory: FirebaseUsernameDirectory(),
            verificationService: FirebaseVerificationService(),
            creatorService: FirebaseCreatorService(),
            appointmentService: FirebaseAppointmentService()
        )
        // A session Firebase dropped signs the app out too (audit 2026-10-10).
        auth.onSessionLost = { [weak store] in
            guard let store, store.authUser != nil else { return }
            store.signOut()
            store.showToast("You were signed out — sign in again to keep backing up.")
        }
        _store = State(initialValue: store)
    }

    var body: some Scene {
        WindowGroup {
            SystemAppearanceMirror { RootView() }
                // Scrolling any page slides the keyboard off and returns
                // to the content under it; screens that chose the
                // follow-the-finger mode (the chats) keep their own.
                .scrollDismissesKeyboard(.immediately)
                // Theme tokens are statics — SwiftUI won't re-run leaf
                // bodies just because a static changed. New identity on the
                // appearance flip rebuilds the whole tree, so every view
                // re-reads the light/dark tokens. One-time cost per flip.
                .id("\(store.appearanceIsLight)-\(store.profileShowcase.accentPalette.rawValue)-\(store.profileShowcase.customAccentHex)")
                .environment(store)
                .preferredColorScheme(store.selectedAppearance)
                .onAppear {
                    // Any window override an older build pinned is cleared,
                    // so sheets and covers follow the iPhone's setting too.
                    MorpheAppStore.applyWindowAppearance(isLight: store.appearanceIsLight)
                    KeyboardSwipeDismisser.shared.install()
                }
                .onReceive(NotificationCenter.default.publisher(for: .morpheIntentArrived)) { _ in
                    // Intent fired while the app was already frontmost —
                    // no scene-phase change to piggyback on.
                    store.consumePendingIntentActions()
                }
                // Midnight while the app stays open (audit 2026-10-10): the
                // Today board and the fuel log used to wait for the next
                // foreground to roll over.
                .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged).receive(on: RunLoop.main)) { _ in
                    store.handleDayRolloverIfNeeded()
                }
                .onChange(of: scenePhase) { _, phase in
                    // A finished session never stays unlogged because the
                    // app was left (fix wave 2026-10-13).
                    if phase == .background { store.logFinishedWorkoutIfPending() }
                    // A calendar day can pass while the app sits suspended in
                    // the switcher — every return to the foreground re-checks
                    // whether "today" is still today.
                    if phase == .active {
                        // The wrist logger's session link (market audit 2026-08).
                        WatchBridge.shared.activate(store: store)
                        store.handleDayRolloverIfNeeded()
                        // Showing up counts (daily streak, 2026-10-04).
                        store.recordAppOpen()
                        // The day popup greets every open (Lucas 2026-08-18).
                        store.reopenDayPopup()
                        // "Hey Morphe" listens only while the app is open.
                        // Fresh foreground = fresh transient-retry budget
                        // (audit 14, P1).
                        store.resetVoiceRetryBudget()
                        store.startVoiceIfEnabled()
                        // Siri / Shortcuts / Action Button (rebuild wave):
                        // "Start my workout in Morphe" left a flag.
                        store.consumePendingIntentActions()
                        // Lock-screen mic: the app opened to listen.
                        store.consumePendingDirectVoiceCapture()
                    }
                    // The log backup debounce is 60s — leaving the app
                    // flushes whatever is pending so a swipe-kill can't
                    // strand the last set locally.
                    if phase == .background {
                        // Real background — the only thing that re-arms the
                        // day takeover on return (audit 12, P1-1).
                        store.noteBackgrounded()
                        store.heyMorphe.stop()
                        store.requestImmediateLogBackup()
                    }
                }
        }
    }
}

/// A downward swipe anywhere on the page puts the keyboard away — the
/// same gesture as scrolling, for the screens (and the pinned consoles)
/// that have nothing to scroll. Lives on the window, so sheets are
/// covered; it never cancels or delays the touches underneath.
final class KeyboardSwipeDismisser: NSObject, UIGestureRecognizerDelegate {
    static let shared = KeyboardSwipeDismisser()
    private var keyboardVisible = false
    private var observing = false

    func install() {
        if !observing {
            observing = true
            let center = NotificationCenter.default
            center.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { [weak self] _ in
                self?.keyboardVisible = true
            }
            center.addObserver(forName: UIResponder.keyboardDidHideNotification, object: nil, queue: .main) { [weak self] _ in
                self?.keyboardVisible = false
            }
        }
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows
            where !(window.gestureRecognizers ?? []).contains(where: { $0.name == Self.recognizerName }) {
                let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
                pan.name = Self.recognizerName
                pan.cancelsTouchesInView = false
                pan.delaysTouchesBegan = false
                pan.delaysTouchesEnded = false
                pan.delegate = self
                window.addGestureRecognizer(pan)
            }
        }
    }

    private static let recognizerName = "morphe.keyboard.swipeDismiss"

    @objc private func handlePan(_ pan: UIPanGestureRecognizer) {
        guard keyboardVisible, pan.state == .changed, let window = pan.view else { return }
        let move = pan.translation(in: window)
        // A deliberate downward swipe: far enough, and more down than sideways
        // (a pager swipe or a horizontal chip scroll is not a dismissal).
        guard move.y > 28, move.y > abs(move.x) * 1.5 else { return }
        window.endEditing(true)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        true
    }

    /// A drag that starts inside a text field is a caret move or a text
    /// selection, never a dismissal. A drag inside a scroll view that chose
    /// the follow-the-finger mode (the chats) is that mode's to handle.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard keyboardVisible else { return false }
        var view = touch.view
        while let current = view {
            if current is UITextField || current is UITextView { return false }
            if let scroll = current as? UIScrollView, scroll.keyboardDismissMode == .interactive { return false }
            view = current.superview
        }
        return true
    }
}

/// Mirrors the iPhone's Light/Dark setting into the store (Lucas
/// 2026-10-06): the token system flips with the system, never from an
/// in-app switch. Sits above every preferredColorScheme, so the scheme it
/// reads is the system's own.
private struct SystemAppearanceMirror<Content: View>: View {
    @Environment(MorpheAppStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme
    @ViewBuilder let content: () -> Content

    @State private var pending = false

    /// A sheet or cover in flight: the theme remount would tear it down
    /// mid-edit (audit 33 — iOS flips appearance at sunset on its own).
    private var somethingPresented: Bool {
        store.showClientProfile || store.showAIAgent || store.showQuickAdd || store.viewingPerson != nil
            || store.showUniversalSearch || store.showProgressSheet
            || store.isWorkoutSessionActive
    }

    var body: some View {
        content()
            .onAppear { sync() }
            .onChange(of: colorScheme) { _, _ in sync() }
            .onChange(of: somethingPresented) { _, presented in
                if !presented, pending { sync() }
            }
    }

    private func sync() {
        let light = colorScheme == .light
        // Tokens ALWAYS follow the live scheme first (2026-10-11): on a cold
        // reopen the store's persisted flag could already match while the
        // token seed (read from screen traits before a scene existed) was
        // wrong — the early return below left text drawn in the field's
        // own color.
        MorpheTheme.isLight = light
        guard store.appearanceIsLight != light else { pending = false; return }
        // The full remount waits until nothing is presented and no session
        // is running.
        if somethingPresented { pending = true; return }
        pending = false
        store.appearanceIsLight = light
    }
}
