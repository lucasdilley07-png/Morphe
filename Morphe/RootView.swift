import SwiftUI
import Speech
import AVFoundation
import UIKit

/// Keyboard visibility for the floating dock (audit 13, P1): the capsule
/// participates in keyboard avoidance, so without this it floated BETWEEN
/// the keyboard and the text field — five tappable tabs a thumb-brush away
/// from every composer. The dock yields while typing, like a system tab bar.
@Observable
final class KeyboardWatcher {
    static let shared = KeyboardWatcher()
    private(set) var isVisible = false
    private var tokens: [NSObjectProtocol] = []

    private init() {
        let center = NotificationCenter.default
        tokens.append(center.addObserver(
            forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.isVisible = true })
        tokens.append(center.addObserver(
            forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.isVisible = false })
    }
}

/// Terms of use + liability waiver. Shown once after onboarding (and on every
/// reopen until accepted). Agree → remembered forever, locally and in the
/// cloud backup. Disagree → signed out; the gate returns on the next sign-in.
struct TermsGateView: View {
    @Environment(MorpheAppStore.self) private var store
    @State private var showDeclineConfirm = false
    /// Read-only mode: the onboarding "read the terms" link shows the SAME
    /// document without the accept/decline controls — one text, two doors.
    var readOnly = false

    private static let sections: [(title: String, body: String)] = [
        ("Not medical advice",
         "Morphe provides general fitness content and tracking tools. It is not medical advice, diagnosis, or treatment, and no part of the app creates a provider–patient relationship. Consult a physician before starting this or any exercise program, especially if you have a medical condition, injury, or are pregnant."),
        ("You assume the risk",
         "Exercise carries inherent risks, including serious injury. You are responsible for training within your own limits, using equipment safely, and stopping immediately if you feel pain, dizziness, or discomfort. You voluntarily assume all risks arising from your use of Morphe."),
        ("Limitation of liability",
         "To the maximum extent permitted by law, Morphe and its creators are not liable for any injury, loss, or damage — direct or indirect — arising from your use of the app, its workouts, its recommendations, or training sessions with other users, whether in person, virtual, or in a group."),
        ("Form Check and AI features",
         "Camera-based form feedback and AI-generated guidance are automated aids, not a substitute for qualified, in-person coaching. They can be wrong. You remain responsible for your own technique and safety."),
        ("Community conduct",
         "Morphe has zero tolerance for objectionable content and abusive users. Content you post can be reported by anyone and is reviewed by a human; you can block any account instantly; repeat or serious abuse ends the account. By using the community features you agree to these rules."),
        ("Your data",
         "Your profile and training history are stored on your device and backed up to your account so you can restore them. You can export everything and delete your account, both from Profile. Don't share your account credentials."),
        ("As is",
         "Morphe is provided \"as is\", without warranties of any kind. Features may change, break, or be removed as the app evolves.")
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: true) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("TERMS OF USE")
                        .font(MorpheTheme.microLabel())
                        .tracking(1.4)
                        .foregroundStyle(MorpheTheme.accentText)
                        .padding(.top, 24)

                    Text("Before you train")
                        .font(.title.weight(.bold))
                        .foregroundStyle(MorpheTheme.textPrimary)

                    Text("Quick but important: read and accept these terms to use Morphe.")
                        .font(.subheadline)
                        .foregroundStyle(MorpheTheme.textSecondary)

                    ForEach(Self.sections, id: \.title) { section in
                        GlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(section.title)
                                    .font(.headline)
                                    .foregroundStyle(MorpheTheme.textPrimary)
                                Text(section.body)
                                    .font(.subheadline)
                                    .foregroundStyle(MorpheTheme.textSecondary)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }

            if !readOnly {
                VStack(spacing: 10) {
                    Button("I Agree") {
                        store.acceptTerms()
                    }
                    .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))

                    Button("I Disagree") {
                        showDeclineConfirm = true
                    }
                    .buttonStyle(SecondaryCTAButtonStyle())
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(.black.opacity(0.35))
            }
        }
        .alert("Decline the terms?", isPresented: $showDeclineConfirm) {
            Button("Sign Out", role: .destructive) {
                store.declineTerms()
            }
            Button("Go Back", role: .cancel) {}
        } message: {
            Text("Morphe can't be used without accepting the terms. You'll be signed out — your data stays backed up to your account.")
        }
    }
}

struct RootView: View {
    @Environment(MorpheAppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Clearance for the floating AI button over the dock. Scales with the
    /// dock's own micro-labels (audit 13, P2): a fixed 74 overlapped the
    /// capsule at accessibility text sizes.
    @ScaledMetric(relativeTo: .caption2) private var aiButtonDockClearance: CGFloat = 74

    /// Reduce Motion swaps travel for a quick crossfade — never zero
    /// feedback, never a slide/spring.
    private var shellAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.1) : .easeInOut(duration: 0.25)
    }

    private var celebrationAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.1) : .spring(response: 0.38, dampingFraction: 0.65)
    }

    /// True only when the real app shell is showing — matches the routing in
    /// `body` (past the launch sequence, the auth wall, and onboarding).
    private var isInAppShell: Bool {
        if store.isShowingLaunchSequence { return false }
        if FeatureFlags.accountsEnabled && store.authUser == nil { return false }
        if !store.hasCompletedOnboarding { return false }
        if store.needsTermsAcceptance { return false }
        if store.showWelcomeExperience { return false }
        return true
    }

    var body: some View {
        @Bindable var store = store
        return ZStack {
            PremiumBackground()

            Group {
                if store.isShowingLaunchSequence {
                    LaunchSequenceView()
                } else if FeatureFlags.accountsEnabled && store.authUser == nil {
                    AuthView()
                } else if store.cloudRestoreBlocked, !store.hasCompletedOnboarding {
                    // The cloud pull FAILED for an account with no local
                    // profile — retry, never onboard over a real backup.
                    VStack(spacing: 16) {
                        Image(systemName: "icloud.slash")
                            .font(.largeTitle)
                            .foregroundStyle(MorpheTheme.textMuted)
                        Text("Couldn't reach your backup")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(MorpheTheme.textPrimary)
                        Text("Your account may have training history in the cloud — Morphe won't set up a fresh profile until it can check. Verify your connection and retry.")
                            .font(.subheadline)
                            .foregroundStyle(MorpheTheme.textSecondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            Task { await store.retryCloudRestore() }
                        }
                        .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                        .frame(width: 160)
                        Button("Sign Out") { store.signOut() }
                            .buttonStyle(.plain)
                            .foregroundStyle(MorpheTheme.textMuted)
                    }
                    .padding(32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(PremiumBackground().ignoresSafeArea())
                } else if !store.hasCompletedOnboarding {
                    OnboardingFlowView()
                } else if store.needsTermsAcceptance {
                    // Terms gate: the app is unreachable until they agree, on
                    // this open and every reopen. Declining signs out.
                    TermsGateView()
                } else {
                    AppShell {
                        // One account type (Lucas 2026-09): everyone gets the
                        // full experience — create, share, track, train together.
                        ClientLayout {
                            ClientExperienceShell()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .preferredColorScheme(store.selectedAppearance)
        .sheet(item: $store.selectedExercise, onDismiss: {
            store.consumePendingDebriefOpen()
        }) { exercise in
            ExerciseDetailView(exercise: exercise)
        }
        .sheet(item: $store.pendingPartnerSessionPost, onDismiss: {
            store.dismissPendingPartnerSessionPost()
            store.consumePendingDebriefOpen()
        }) { draft in
            NavigationStack {
                PartnerSessionPostSheet(draft: draft)
                    .environment(store)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .background(PremiumBackground())
        }
        .sheet(item: $store.selectedNetworkProfile, onDismiss: {
            store.closeNetworkProfile()
            store.consumePendingDebriefOpen()
        }) { profile in
            NavigationStack {
                NetworkProfilePreviewSheet(profile: profile)
                    .environment(store)
            }
            .sheetToastSurface()
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .background(PremiumBackground())
        }
        .sheet(isPresented: $store.showClientProfile, onDismiss: {
            store.closeClientProfile()
            // "See your history, records, and charts" queued a progress
            // open — two sheets can't co-present, so it raises here.
            store.consumePendingProgressOpen()
            store.consumePendingDebriefOpen()
        }) {
            NavigationStack {
                // ProfileView owns its Done button: it has to check for
                // unsaved edits (drafts live in its @State) before closing.
                ProfileView()
                    .environment(store)
            }
            .sheetToastSurface()
            .background(PremiumBackground())
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $store.showProgressSheet, onDismiss: {
            // The Progress sheet blocks the debrief consume guard — its
            // dismissal must be a consume site too, or a co-queued
            // debrief starves behind it forever (audit 19, P1).
            store.consumePendingDebriefOpen()
        }) {
            NavigationStack {
                // ProgressScreenView owns its scroll — same view the old
                // tab hosted, now a sheet.
                ProgressScreenView()
                    .environment(store)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { store.showProgressSheet = false }
                                .foregroundStyle(MorpheTheme.accentText)
                        }
                    }
            }
            .sheetToastSurface()
            .background(PremiumBackground())
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $store.showUniversalSearch, onDismiss: {
            store.consumePendingProgressOpen()
            store.consumePendingDebriefOpen()
        }) {
            NavigationStack {
                UniversalSearchSheet()
                    .environment(store)
            }
            .background(PremiumBackground())
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $store.showQuickAdd, onDismiss: {
            // Retires the 0.6s guess-timer: if Ask Morphe queued the AI
            // cover, open it the moment THIS sheet has actually gone —
            // the completion fires exactly when the transition has room.
            if store.pendingAIAgentOpen {
                store.pendingAIAgentOpen = false
                store.openAIAgent()
            }
            store.consumePendingProgressOpen()
            store.consumePendingDebriefOpen()
        }) {
            NavigationStack {
                QuickAddSheet()
                    .environment(store)
            }
            .background(PremiumBackground())
            // Quick actions get a quick sheet (HIG): medium detent first,
            // expandable when the note editor needs room.
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $store.showAIAgent, onDismiss: {
            // A chat/voice "show my progress" closed this cover with the
            // sheet queued (audit 15, P1).
            store.consumePendingProgressOpen()
            store.consumePendingDebriefOpen()
        }) {
            NavigationStack {
                MorpheAIAgentSheet()
                    .environment(store)
            }
            // Chat deliberately never queues the session-work gate (it
            // declines with an honest reply instead), so no dialog host here —
            // sheet teardown writing through the shared binding could cancel
            // a pending change.
            .background(PremiumBackground())
        }
        .sheet(isPresented: $store.showWelcomeExperience) {
            WelcomeExperienceView()
                .environment(store)
        }
        .sessionWorkGateDialog()
        .alert("Save more workouts to switch", isPresented: $store.showSwitchNeedsSavedWorkouts) {
            Button("Open Discover") {
                store.showDiscoverTab()
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text("Switch rotates between the workouts you've saved. Save some from Discover — or build your own in Train — and they'll show up here.")
        }
        // The full-screen day takeover — covers the tab bar; every open.
        .overlay {
            MorpheDayPopup()
                .environment(store)
        }
        .animation(.easeInOut(duration: 0.3), value: store.shouldShowDayPopup)
        // "Hey Morphe" edge glow + exchange chip — ABOVE the takeover
        // (audit 12, P2-1): voice works during it, so it must be visible
        // during it.
        .overlay {
            if store.heyMorphe.state == .active || store.heyMorphe.state == .speaking {
                VoiceGlowOverlay()
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .top) {
            // Live transcript leads while capturing (rebuild 2026-08);
            // the heard/answer chip takes over once the command fires.
            if store.heyMorphe.state == .active, !store.heyMorphe.liveTranscript.isEmpty {
                VoiceTranscriptPill(text: store.heyMorphe.liveTranscript)
                    .padding(.top, 118)
                    .padding(.horizontal, 24)
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else if let exchange = store.lastVoiceExchange {
                VoiceExchangeChip(heard: exchange.heard, answer: exchange.answer)
                    .padding(.top, 118)
                    .padding(.horizontal, 24)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: store.heyMorphe.state)
        .animation(.easeInOut(duration: 0.25), value: store.heyMorphe.liveTranscript)
        .animation(.easeInOut(duration: 0.3), value: store.lastVoiceExchange?.answer)
        // The once-ever hello (Apple benchmark A6) — topmost, brief, gone.
        .overlay {
            if store.showHelloBeat {
                HelloBeatOverlay()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: store.showHelloBeat)
        .overlay(alignment: .top) {
            VStack(spacing: 10) {
                if let toast = store.toastMessage {
                    ToastBanner(text: toast)
                        // Clears the floating icon row (52pt) instead of
                        // drawing over the avatar/quick-add buttons.
                        .padding(.top, 64)
                        .transition(reduceMotion
                            ? .opacity
                            : .move(edge: .top).combined(with: .opacity))
                }

                if let celebration = store.celebration {
                    CelebrationOverlay(moment: celebration)
                        .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 20)
        }
        .overlay(alignment: .bottomTrailing) {
            // Only in the real app shell — never over the sign-in or onboarding
            // screens (a signed-out account still has hasCompletedOnboarding set).
            // And never over the day takeover (audit 13, P2): the popup is the
            // character's center-stage moment and already has its own AI door.
            if isInAppShell && !store.shouldShowDayPopup {
                FloatingAIAgentButton()
                    .padding(.trailing, 20)
                    // Clears the floating glass capsule (~57pt + 6pt inset),
                    // growing with the dock's labels at accessibility sizes.
                    .padding(.bottom, aiButtonDockClearance)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        // The escalated moment (PRs, finished programs) — full-screen and
        // attached LAST so it covers everything, including the floating AI
        // button. Dismissed only by the user.
        .overlay {
            if let stamp = store.recordStamp {
                RecordStampOverlay(
                    moment: stamp,
                    caption: store.shareCardCaption,
                    onShareCompleted: { store.noteShareCardShared(.pr) },
                    onDismiss: { store.dismissRecordStamp() }
                )
                .transition(reduceMotion ? .opacity : .scale(scale: 1.06).combined(with: .opacity))
            }
        }
        // Reduce Motion: crossfades instead of moves/springs — the beats
        // still land, they just don't travel.
        .animation(shellAnimation, value: store.selectedClientTab)
        .animation(shellAnimation, value: store.toastMessage)
        // The celebrations are the app's ONE emotional beat — the banner and
        // the full-screen stamp get a spring pop where everything else stays
        // mechanical.
        .animation(celebrationAnimation, value: store.celebration)
        .animation(celebrationAnimation, value: store.recordStamp)
        // Referral deep links (morphe://invite/<username>) land here whether
        // the app was cold-launched or already running.
        .onOpenURL { url in
            store.handleIncomingURL(url)
        }
    }
}

private struct PartnerSessionPostSheet: View {
    @Environment(MorpheAppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let draft: PartnerSessionPostDraft

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                SectionTitleView(
                    title: "Partner Session Ready",
                    subtitle: "Morphe turned your shared session into a clean post card. Share it, save it, or skip it."
                )

                GlassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("🔥 \(store.clientProfile.name)")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(MorpheTheme.textPrimary)
                                Text("with \(draft.partnerAvatar) \(draft.partnerName)")
                                    .font(.caption)
                                    .foregroundStyle(MorpheTheme.textSecondary)
                            }

                            Spacer()

                            StatusBadge(text: "Partner Session", color: MorpheTheme.warning)
                        }

                        Text(draft.workoutTitle)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(MorpheTheme.textPrimary)

                        Text(draft.detail)
                            .font(.subheadline)
                            .foregroundStyle(MorpheTheme.textSecondary)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                            MetricPill(label: "Mode", value: draft.mode.rawValue)
                            MetricPill(label: "Minutes", value: "\(draft.durationMinutes)")
                            MetricPill(label: "XP bonus", value: "+\(draft.xpBonus)")
                            MetricPill(label: "Partner streak", value: "\(draft.partnerStreak) days")
                        }

                        if !draft.tags.isEmpty {
                            WrapStack(spacing: 8) {
                                ForEach(draft.tags, id: \.self) { tag in
                                    StatusBadge(text: tag, color: MorpheTheme.accentAlt)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Shared challenge")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(MorpheTheme.textMuted)
                            Text(draft.miniChallenge)
                                .font(.subheadline)
                                .foregroundStyle(MorpheTheme.textPrimary)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                                .fill(MorpheTheme.panel)
                                .overlay(
                                    RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                                        .stroke(MorpheTheme.stroke.opacity(0.8), lineWidth: 1)
                                )
                        )
                    }
                }

                HStack(spacing: 12) {
                    Button("Not Now") {
                        store.dismissPendingPartnerSessionPost()
                        dismiss()
                    }
                    .buttonStyle(SecondaryCTAButtonStyle())

                    Button("Save Recap") {
                        store.savePendingPartnerSessionRecap()
                        dismiss()
                    }
                    .buttonStyle(SecondaryCTAButtonStyle())

                    Button("Share Post") {
                        store.sharePendingPartnerSessionPost()
                        dismiss()
                    }
                    .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    store.dismissPendingPartnerSessionPost()
                    dismiss()
                }
                .foregroundStyle(MorpheTheme.textPrimary)
            }
        }
    }
}

private struct ClientExperienceShell: View {
    @Environment(MorpheAppStore.self) private var store

    var body: some View {
        @Bindable var store = store
        // The custom bottom bar is the only navigator — the system tab bar is
        // hidden per tab, and the page style is gone so horizontal chip rows
        // and carousels don't fight an edge-swipe pager.
        return TabView(selection: $store.selectedClientTab) {
            // Each screen's identity is keyed off tabResetKey, so tapping the
            // tab icon rebuilds it at its root (top of page, drill-ins
            // closed). Train is deliberately NOT keyed — a tab tap must never
            // reset a live session or running rest timer.
            HomeView()
                .id(store.tabResetKey("today"))
                .toolbar(.hidden, for: .tabBar)
                .tag(ClientTab.today)

            WorkoutView()
                .toolbar(.hidden, for: .tabBar)
                .tag(ClientTab.train)

            // Un-gated: the For You feed is REAL now (Firestore posts).
            // CommunityView gates its own demo-only sections internally.
            CommunityView()
                // Keyed like the other tabs: re-tapping Network lands back
                // at the top of a fresh feed instead of doing nothing.
                .id(store.tabResetKey("community"))
                .toolbar(.hidden, for: .tabBar)
                .tag(ClientTab.community)

            // Discover is a first-class tab again; Progress presents as a
            // sheet from the profile row and the old doors (Lucas 2026-08-26).
            DiscoverScreenView()
                .id(store.tabResetKey("discover"))
                .toolbar(.hidden, for: .tabBar)
                .tag(ClientTab.discover)

            MoreView()
                .id(store.tabResetKey("more"))
                .toolbar(.hidden, for: .tabBar)
                .tag(ClientTab.more)
        }
        .safeAreaInset(edge: .top) {
            // Icons only — no band, no hairline. The short ink→clear fade
            // (same scrim the coach header uses) keeps the STATUS BAR
            // readable and stops content ghosting up between the icons,
            // without bringing the solid band back.
            ClientPinnedHeader()
                .padding(.horizontal, 16)
                .background(
                    LinearGradient(
                        colors: [
                            MorpheTheme.ink.opacity(0.96),
                            MorpheTheme.ink.opacity(0.80),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea(edges: .top)
                )
        }
        .safeAreaInset(edge: .bottom) {
            // Floating glass capsule (b866e53) — inset from the bottom and
            // sides; the root ink shows around it. Yields to the keyboard
            // (audit 13, P1) instead of floating on top of it.
            if !KeyboardWatcher.shared.isVisible {
                BottomTabNavigation(items: ClientTab.visibleCases, selected: store.selectedClientTab) { tab in
                    store.selectedClientTab = tab
                    // Tapping the icon always lands at the top of that tab's
                    // first page.
                    store.popTabToRoot(tab.rawValue)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: KeyboardWatcher.shared.isVisible)
    }
}

private struct ClientPinnedHeader: View {
    @Environment(MorpheAppStore.self) private var store

    var body: some View {
        // Icons only — no name/handle strip. The avatar IS the profile
        // button; VoiceOver still gets the words.
        HStack(spacing: 12) {
            Button {
                store.openClientProfile()
            } label: {
                MorpheAvatarView(avatar: store.profileShowcase.avatar, size: 40,
                                 photoData: store.profilePhotoData)
                    // The avatar tile's own fill is 6%-white — floating over
                    // scrolling content it needs a truly opaque face, same
                    // as the quick-add button.
                    .background(
                        RoundedRectangle(cornerRadius: MorpheTheme.radiusSmall, style: .continuous)
                            .fill(MorpheTheme.ink)
                    )
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Profile"))

            Spacer()

            // The universal search sheet existed fully built with no way
            // in — this is its (only) front door.
            HeaderCircleButton(systemImage: "magnifyingglass", label: "Search") {
                store.openUniversalSearch()
            }

            HeaderCircleButton(systemImage: "plus", label: "Quick add") {
                store.openQuickAdd()
            }

            // This button opens the demo Contact inbox — still a multi-user
            // surface. REAL coach messaging lives on the Today "Coach" card
            // (only shown once a claimed coach thread exists).
            if FeatureFlags.multiUserEnabled {
                HeaderCircleButton(systemImage: "bubble.left.and.bubble.right.fill", label: "Messages") {
                    store.openCommunity(.contact)
                }
            }
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 4)
        // No hairline, no band — icons only, page content indented below.
    }
}

// (DemoBrandHeader removed — the old solid header band, orphaned by the
// icons-only floating header.)

private struct HeaderCircleButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(.subheadline).weight(.semibold))
                .foregroundStyle(MorpheTheme.textPrimary)
                .frame(width: 44, height: 44)
                // Solid fill: the button floats OVER scrolling content, so
                // its face must be opaque — never text showing through.
                .background(
                    RoundedRectangle(cornerRadius: MorpheTheme.radiusSmall, style: .continuous)
                        .fill(MorpheTheme.ink)
                )
                .overlay(
                    // Same radius as the fill (audit 13, P2): a 16pt stroke
                    // over an 8pt fill left the hairline floating off the
                    // corners on every header button.
                    RoundedRectangle(cornerRadius: MorpheTheme.radiusSmall, style: .continuous)
                        .stroke(MorpheTheme.stroke, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }
}

private struct FloatingAIAgentButton: View {
    @Environment(MorpheAppStore.self) private var store

    private var label: String { "Morphe AI" }

    private var isCompact: Bool {
        // The wide "Morphe AI" pill exists to introduce the feature — after
        // the user has opened it once, it earns its keep as a small circle
        // that stops floating over bottom-right content on every tab.
        // A live Train session always compacts (screen space is training's).
        store.hasUsedAIAgent
            || (store.selectedClientTab == .train && store.isWorkoutSessionActive)
    }

    var body: some View {
        Button {
            store.openAIAgent()
        } label: {
            Group {
                if isCompact {
                    Image(systemName: "sparkles")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(MorpheTheme.textPrimary)
                        .frame(width: 50, height: 50)
                        .background(buttonBackground.clipShape(Circle()))
                } else {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.subheadline.weight(.bold))
                        Text(label)
                            .font(.subheadline.weight(.bold))
                    }
                    .foregroundStyle(MorpheTheme.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(buttonBackground)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Open \(label)"))
        .contextMenu {
            ForEach(store.aiAgentQuickPrompts.prefix(4), id: \.self) { prompt in
                Button(prompt) {
                    // Open FIRST, then send: navigation actions close the
                    // sheet in the same transaction (never presents), while
                    // conversational replies AND action declines ("you have
                    // an unlogged session…") stay visible. The old
                    // open-on-false logic swallowed declines entirely.
                    store.openAIAgent()
                    store.sendAIAgentPrompt(prompt)
                }
            }
        }
    }

    private var buttonBackground: some View {
        // Flat HUD capsule: solid ink so it stays legible over any scroll
        // content, one accent hairline as the identity.
        Capsule(style: .continuous)
            .fill(MorpheTheme.ink.opacity(0.97))
            .overlay(
                Capsule(style: .continuous)
                    .stroke(MorpheTheme.accent.opacity(0.55), lineWidth: 1)
            )
    }
}

private struct MorpheAIAgentSheet: View {
    @Environment(MorpheAppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var prompt = ""
    @State private var dictation = DictationEngine()
    @FocusState private var inputFocused: Bool

    private var messages: [ThreadMessage] {
        store.athleteAIAgentConversation
    }

    private var trimmedPrompt: String {
        prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        // One full-screen chat surface: the conversation fills the page and
        // the composer is pinned to the bottom — no separate "Morphe AI" and
        // "Ask Morphe" cards.
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(store.aiAgentSubtitle)
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 4)

                    // Fresh-chat starters (the ChatGPT pattern): big
                    // tappable cards while the chat is empty, gone the
                    // moment a conversation exists. Every starter is a
                    // prompt the action/answer layers actually handle.
                    if messages.count <= 1 {
                        VStack(spacing: 10) {
                            ForEach(store.aiAgentQuickPrompts.prefix(4), id: \.self) { starter in
                                Button {
                                    prompt = starter
                                    send()
                                } label: {
                                    HStack {
                                        Text(starter)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(MorpheTheme.textPrimary)
                                            .multilineTextAlignment(.leading)
                                        Spacer()
                                        Image(systemName: "arrow.up.right")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(MorpheTheme.accentText)
                                    }
                                    .padding(14)
                                    .background(
                                        RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                                            .fill(MorpheTheme.panel)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                                                    .stroke(MorpheTheme.stroke, lineWidth: 1)
                                            )
                                    )
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, 12)
                    }

                    ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                        AIAgentMessageRow(
                            message: message,
                            isFirstInRun: index == 0 || messages[index - 1].sender != message.sender
                        )
                        .id(message.id)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .onAppear {
                if let last = messages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
            .onChange(of: messages.count) {
                guard let last = messages.last else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
        .safeAreaInset(edge: .bottom) { composerBar }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    store.resetAIAgentConversation()
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(MorpheTheme.textPrimary)
                .accessibilityLabel("New chat")
            }
            ToolbarItem(placement: .principal) {
                Text("Morphe AI")
                    .font(.headline)
                    .foregroundStyle(MorpheTheme.textPrimary)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    store.closeAIAgent()
                    dismiss()
                }
                .foregroundStyle(MorpheTheme.textPrimary)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Full-width composer pinned to the bottom of the chat.
    private var composerBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text("Context".uppercased())
                    .font(MorpheTheme.microLabel(10))
                    .tracking(1.2)
                    .foregroundStyle(MorpheTheme.textMuted)
                Text(store.aiAgentContextLabel)
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textSecondary)
                    .lineLimit(1)
                Spacer()
            }

            // One capsule, everything inside (the ChatGPT composer shape):
            // field grows, mic and send live in the same container.
            HStack(alignment: .bottom, spacing: 6) {
                TextField(
                    store.aiAgentPlaceholder,
                    text: $prompt,
                    axis: .vertical
                )
                .lineLimit(1...4)
                .foregroundStyle(MorpheTheme.textPrimary)
                .padding(.leading, 14)
                .padding(.vertical, 11)
                .focused($inputFocused)

                Button {
                    toggleDictation()
                } label: {
                    Image(systemName: dictation.isRecording ? "mic.fill" : "mic")
                        .font(.system(size: 22))
                        .foregroundStyle(dictation.isRecording ? MorpheTheme.accent : MorpheTheme.textSecondary)
                        .symbolEffect(.pulse, isActive: dictation.isRecording)
                        // 44pt minimum hit target — the glyph alone is too
                        // small to tap reliably mid-workout.
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(dictation.isRecording ? "Stop dictation" : "Dictate message")

                Button(action: send) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(trimmedPrompt.isEmpty ? MorpheTheme.textMuted : MorpheTheme.accent)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(trimmedPrompt.isEmpty)
                .accessibilityLabel("Send")
            }
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(MorpheTheme.panelStrong)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(MorpheTheme.stroke, lineWidth: 1)
                    )
            )

            if let notice = dictation.notice {
                Text(notice)
                    .font(.caption2)
                    .foregroundStyle(MorpheTheme.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(
            MorpheTheme.ink.opacity(0.97)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(MorpheTheme.stroke)
                        .frame(height: 1)
                }
                .ignoresSafeArea(edges: .bottom)
        )
        .onDisappear { dictation.stop() }
    }

    private func send() {
        let text = trimmedPrompt
        guard !text.isEmpty else { return }
        // Clear FIRST — the box must be empty the instant the arrow is hit,
        // even when the prompt triggers navigation that tears the sheet down.
        prompt = ""
        dictation.stop()
        store.sendAIAgentPrompt(text)
    }

    private func toggleDictation() {
        if dictation.isRecording {
            dictation.stop()
        } else {
            // Dictation APPENDS to whatever is already typed — switching from
            // thumbs to voice mid-thought must not eat the typed half.
            dictation.start(baseText: prompt) { prompt = $0 }
        }
    }
}

private struct AIAgentMessageRow: View {
    let message: ThreadMessage
    /// True when this message starts a run from its sender. Only run leaders
    /// carry the name caption, so back-to-back replies read as one voice.
    var isFirstInRun: Bool = true

    private var isUser: Bool { message.sender == .user }

    var body: some View {
        // iMessage shape: the bubble hugs its text (capped at ~75% of the
        // row) and sits on its sender's side — full-width slabs made every
        // message look like the same speaker.
        HStack(spacing: 0) {
            if isUser { Spacer(minLength: 0) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                if isFirstInRun {
                    Text(message.senderName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MorpheTheme.textMuted)
                }

                Group {
                    if !isUser && message.text == "\u{2026}" {
                        // Morphe is thinking — the placeholder breathes
                        // instead of sitting as dead dots (feedback pass
                        // 2026-09); reduceMotion falls back to static.
                        Image(systemName: "ellipsis")
                            .font(.subheadline)
                            .foregroundStyle(MorpheTheme.textSecondary)
                            .symbolEffect(.variableColor.iterative, options: .repeating)
                    } else {
                        Text(message.text)
                            .font(.subheadline)
                            .foregroundStyle(MorpheTheme.textPrimary)
                            .contentTransition(.opacity)
                    }
                }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                            .fill(isUser ? MorpheTheme.accentAlt.opacity(0.28) : MorpheTheme.panelStrong)
                    )
                    .animation(.easeOut(duration: 0.2), value: message.text)
                    .contextMenu {
                        Button {
                            UIPasteboard.general.string = message.text
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                    }
            }
            // Fixed cap instead of UIScreen.main (deprecated for multi-scene;
            // wrong under Stage Manager). 300pt ≈ 75% of the narrowest iPhone
            // and reads fine on every width.
            .frame(maxWidth: 300, alignment: isUser ? .trailing : .leading)

            if !isUser { Spacer(minLength: 0) }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }
}

// MARK: - Speech dictation (talk-to-text for the AI composer)

/// "Hey Morphe" (Jarvis wave): hands-free voice while the app is OPEN.
/// One continuous on-device recognition stream scans for the wake phrase;
/// hearing it flips to active capture until a ~1.4s pause, then hands the
/// command to the store's router and speaks the answer back. iOS does not
/// allow third-party wake words in the background or from the lock screen
/// — this is foreground-only by platform rule, and the settings copy says
/// so. Recognition is forced on-device where the hardware supports it.
@Observable
final class HeyMorpheEngine: NSObject, AVSpeechSynthesizerDelegate {
    enum VoiceState {
        case off
        case passive
        case active
        case speaking
    }

    /// One engine per process — dictation and video capture coordinate
    /// through this instead of fighting over the shared audio hardware
    /// (audit 12, P0-3).
    static let shared = HeyMorpheEngine()

    private(set) var state: VoiceState = .off
    private(set) var liveTranscript = ""
    var onWake: (() -> Void)?
    /// (command, isFollowUp). A follow-up command was spoken in the short
    /// window after Morphe answered — no wake phrase required, and the
    /// store routes it doors-only (rebuild 2026-08).
    var onCommand: ((String, Bool) -> Void)?
    /// Honest failure surface (audit 12, P1-3) — PERMANENT conditions only:
    /// permission denied, unsupported language, no on-device recognition.
    /// The owner should flip the feature off.
    var onFailure: ((String) -> Void)?
    /// A recoverable stall (audit 14): the restart ceiling hit, but nothing
    /// about the device changed. The owner should keep the toggle ON and
    /// re-arm later — the old path disabled the feature on any hiccup,
    /// which is exactly "it stopped working and I don't know why".
    var onTransientPause: ((String) -> Void)?

    /// Open until this instant, a command may be spoken WITHOUT the wake
    /// phrase (the Siri back-to-back pattern): set when Morphe finishes
    /// speaking, ~6s wide, date-bounded so stale state can't linger.
    private var followUpDeadline: Date?
    /// True while the current active capture came from the follow-up
    /// window rather than a wake phrase — the transcript has no wake to
    /// strip, and the command fires with isFollowUp so the store stays
    /// silent on non-door chatter.
    private var activeIsFollowUp = false
    /// When the current follow-up capture began — the ceiling that keeps
    /// continuous background speech from holding the capture (and the
    /// transcript pill) hostage until the recognizer's stream cap
    /// (audit 17, P1).
    private var followUpCaptureStart: Date?
    /// True while the current capture came from the lock-screen mic
    /// (Lucas 2026-08-30): whole-stream capture like a follow-up, but
    /// with FULL routing — the user explicitly asked to talk.
    private var directCaptureSession = false

    private var suspendedByExternalAudio = false
    /// True from pauseForExternalAudio to resumeAfterExternalAudio even if
    /// the engine was already off — start() checks it so a scene-phase
    /// restart can't arm the mic while dictation/capture owns it, and it
    /// survives stop() (which only clears the self-suspension).
    private var externalAudioActive = false
    private var restartAttempts = 0
    private var speakingWatchdog: Timer?
    /// When the current listen pass started — a pass that survived a while
    /// was healthy, so its eventual end is a routine recycle, not a failure.
    private var listenStartedAt: Date?
    private var interruptionObserver: NSObjectProtocol?
    /// Audio courtesy (Lucas 2026-08-27): opening the app must NEVER pause
    /// another app's music — bringing a record session up from cold forces
    /// a route renegotiation that stops other audio, mixWithOthers or not.
    /// True while the engine is deliberately parked behind someone else's
    /// audio; the silence-secondary-audio hint re-arms it the moment the
    /// other audio ends.
    private var waitingForQuiet = false
    private var quietHintObserver: NSObjectProtocol?
    /// The quiet HINT only delivers to apps with an ACTIVE session — a
    /// parked engine's is inactive, so the observer alone is decorative
    /// (audit 16, P1). This cheap poll is the real re-arm: a property
    /// read every 5s, zero courtesy risk, killed on stop()/arm.
    private var quietPollTimer: Timer?

    private let audioEngine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let synthesizer = AVSpeechSynthesizer()
    /// The best installed en-GB male voice wins (premium > enhanced >
    /// compact — "Daniel" ships on every iPhone; an enhanced or premium
    /// download upgrades Morphe automatically). Falls back to the
    /// system's default British voice, then the device default.
    private static let morpheVoice: AVSpeechSynthesisVoice? = {
        let rank: (AVSpeechSynthesisVoiceQuality) -> Int = {
            switch $0 {
            case .premium: return 2
            case .enhanced: return 1
            default: return 0
            }
        }
        let britishMales = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == "en-GB" && $0.gender == .male }
        return britishMales.max(by: { rank($0.quality) < rank($1.quality) })
            ?? AVSpeechSynthesisVoice(language: "en-GB")
    }()
    private var commandTimer: Timer?
    /// The recognizer has never heard of "Morphe" and transcribes what it
    /// knows — "Hey Murphy" above all (audit 14). Two defenses: the request
    /// carries contextualStrings biasing it toward the real name, and the
    /// wake regex accepts every mis-hearing observed or plausible. Longer
    /// alternatives listed first so "murphy" wins over "murph" and the
    /// command never inherits a stray trailing syllable.
    /// The optional possessive eats the recognizer's retro-corrected
    /// "Hey Murphy's what's…" form (audit 14, P2: the bare \b left a stray
    /// "s " prefix that defeated the question detector downstream).
    private static let wakePattern = try! NSRegularExpression(
        pattern: "\\bhey[,!.]?\\s+(morpheus|morphee|morphie|morphine|morphy|morphe|morph|murphy|murph|more\\s+fee|morfe)(?:'s|\u{2019}s)?\\b[,!.]?",
        options: [.caseInsensitive])

    /// Vocabulary bias for the recognition request: the wake name plus the
    /// doors it opens, so both halves of "hey Morphe, open the leaderboard"
    /// transcribe the way the router expects.
    private static let contextualVocabulary = [
        "Morphe", "hey Morphe", "minimum win", "leaderboard", "weekly board",
        "start my workout", "log", "sets", "reps", "streak", "lessons",
        // Session vocabulary (Lucas 2026-08-27): the whole live console
        // answers to voice, so its command words get the same bias.
        "same as last time", "extra set", "skip rest", "start rest",
        "form check", "delete last set", "warmup", "finish workout",
        "next exercise", "previous exercise"
    ]

    override init() {
        super.init()
        synthesizer.delegate = self
        // Re-arm the parked engine the moment the other app's audio ends
        // (Lucas 2026-08-27: the mic never comes up over someone's music).
        quietHintObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.silenceSecondaryAudioHintNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            guard let self,
                  let raw = note.userInfo?[AVAudioSessionSilenceSecondaryAudioHintTypeKey] as? UInt,
                  AVAudioSession.SilenceSecondaryAudioHintType(rawValue: raw) == .end,
                  self.waitingForQuiet else { return }
            self.waitingForQuiet = false
            self.start()
        }
        // Phone calls / Siri / other apps taking the session (audit 12,
        // P1-4): tear down on interruption, resume when it ends.
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let self,
                  let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
            switch type {
            case .began:
                if self.state != .off { self.tearDownRecognition() }
                // A call mid-capture froze the glow and the new transcript
                // pill on screen for the whole interruption (audit 17,
                // P2) — demote to passive so the chrome clears.
                if self.state == .active {
                    self.state = .passive
                    self.activeIsFollowUp = false
                    self.liveTranscript = ""
                }
            case .ended:
                // The system says whether resuming is appropriate — a call
                // that routed audio elsewhere advises against re-grabbing.
                let optRaw = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt
                let options = AVAudioSession.InterruptionOptions(rawValue: optRaw ?? 0)
                guard self.state == .passive || self.state == .active else { break }
                // The interrupter may still be playing (a music app took
                // the session for good) — re-grabbing would pause it again
                // (Lucas 2026-08-27). Park; the quiet hint re-arms.
                if AVAudioSession.sharedInstance().isOtherAudioPlaying {
                    self.parkForOtherAudio(handback: true)
                    break
                }
                self.state = .passive
                if options.contains(.shouldResume) {
                    self.beginListening()
                } else {
                    // Yield now, self-heal shortly — never parked forever.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                        guard let self, self.state == .passive, self.task == nil else { return }
                        self.beginListening()
                    }
                }
            @unknown default:
                break
            }
        }
    }

    deinit {
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }
        if let quietHintObserver {
            NotificationCenter.default.removeObserver(quietHintObserver)
        }
    }

    /// Parks the engine behind someone else's audio WITH the full session
    /// handback (audit 16, P1: the bare park left the sound-effects owner
    /// flag set and a record category behind — the next reward ding could
    /// re-pause the very music the park was protecting).
    private func parkForOtherAudio(handback: Bool) {
        tearDownRecognition()
        liveTranscript = ""
        state = .off
        if handback {
            SoundEffects.externalAudioOwner = false
            let session = AVAudioSession.sharedInstance()
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
            try? session.setCategory(.ambient, options: [.mixWithOthers])
        }
        waitingForQuiet = true
        startQuietPoll()
    }

    private func startQuietPoll() {
        quietPollTimer?.invalidate()
        let timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self, self.waitingForQuiet else {
                    self?.quietPollTimer?.invalidate()
                    self?.quietPollTimer = nil
                    return
                }
                if !AVAudioSession.sharedInstance().isOtherAudioPlaying {
                    self.waitingForQuiet = false
                    self.quietPollTimer?.invalidate()
                    self.quietPollTimer = nil
                    self.start()
                }
            }
        }
        quietPollTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func start() {
        // While dictation or video capture owns the mic, a scene-phase
        // .active restart must not re-arm the wake engine underneath it —
        // resumeAfterExternalAudio is the only door back (audit 13).
        guard state == .off, !externalAudioActive else { return }
        // Audio courtesy (Lucas 2026-08-27): if another app is playing,
        // stay down — arming a record session from cold pauses their
        // audio. The quiet-hint observer re-arms when it ends, and every
        // foreground return retries through here too.
        if AVAudioSession.sharedInstance().isOtherAudioPlaying {
            // No handback needed — nothing was armed yet.
            waitingForQuiet = true
            startQuietPoll()
            return
        }
        waitingForQuiet = false
        quietPollTimer?.invalidate()
        quietPollTimer = nil
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                guard status == .authorized else {
                    self?.onFailure?("Enable Speech Recognition for Morphe in Settings to use Hey Morphe.")
                    return
                }
                AVAudioApplication.requestRecordPermission { granted in
                    DispatchQueue.main.async {
                        guard let self, self.state == .off else { return }
                        guard granted else {
                            self.onFailure?("Enable the Microphone for Morphe in Settings to use Hey Morphe.")
                            return
                        }
                        self.restartAttempts = 0
                        self.state = .passive
                        self.beginListening()
                    }
                }
            }
        }
    }

    func stop() {
        state = .off
        // A user-level stop is not a pause: the resume hook must not
        // restart a mic the user turned off (audit 13) — and a parked
        // engine must not ghost-arm when the music ends.
        suspendedByExternalAudio = false
        waitingForQuiet = false
        quietPollTimer?.invalidate()
        quietPollTimer = nil
        liveTranscript = ""
        // The follow-up window must not survive a stop (audit 17, P2):
        // backgrounding inside the 6s and returning would honor a stale
        // window in a context where no answer was just given.
        followUpDeadline = nil
        activeIsFollowUp = false
        directCaptureSession = false
        followUpCaptureStart = nil
        tearDownRecognition()
        speakingWatchdog?.invalidate()
        speakingWatchdog = nil
        synthesizer.stopSpeaking(at: .immediate)
        // Give the session BACK (audit 12, P0-2): the app's sounds are
        // .ambient — mix with the user's music, respect the silent switch.
        SoundEffects.externalAudioOwner = false
        let session = AVAudioSession.sharedInstance()
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
        try? session.setCategory(.ambient, options: [.mixWithOthers])
    }

    /// Dictation and video capture call these so exactly one engine owns
    /// the mic at a time (audit 12, P0-3). Flag set AFTER stop() — stop
    /// clears it.
    func pauseForExternalAudio() {
        externalAudioActive = true
        guard state != .off else { return }
        synthesizer.stopSpeaking(at: .immediate)
        stop()
        suspendedByExternalAudio = true
    }

    /// Fires whenever external audio hands the mic back and the engine has
    /// nothing to resume itself (audit 14, P2): a transient retry that
    /// landed DURING dictation was consumed by the `externalAudioActive`
    /// guard, leaving the toggle on over a dead mic until the next
    /// foreground. The store hooks this to re-attempt start().
    var onExternalAudioEnded: (() -> Void)?

    func resumeAfterExternalAudio() {
        externalAudioActive = false
        guard suspendedByExternalAudio else {
            // Not ours to resume — but a retry may have burned while the
            // mic was borrowed. Let the owner re-arm if it wants to.
            if state == .off { onExternalAudioEnded?() }
            return
        }
        suspendedByExternalAudio = false
        // Music that started during dictation/capture wins the session —
        // park instead of re-grabbing over it (Lucas 2026-08-27). Handback
        // included (audit 16, P2: dictation left the session active, and
        // the duckOthers contract un-ducks only on DEACTIVATION — without
        // this the borrowed-mic flow left the music quiet).
        if AVAudioSession.sharedInstance().isOtherAudioPlaying {
            parkForOtherAudio(handback: true)
            return
        }
        restartAttempts = 0
        state = .passive
        beginListening()
    }

    /// Speaks an answer, then returns to passive listening. The mic is torn
    /// down while speaking so the engine never transcribes its own voice.
    func speak(_ text: String) {
        guard state != .off else { return }
        // Nothing to say must NOT park the engine (audit 13, P2): the
        // command path already tore recognition down expecting speech to
        // hand the mic back — go straight back to listening instead.
        guard !text.isEmpty else {
            state = .passive
            beginListening()
            return
        }
        state = .speaking
        tearDownRecognition()
        // Duck only while Morphe is actually talking (audit 13, P1) —
        // beginListening restores .mixWithOthers when the mic returns.
        try? AVAudioSession.sharedInstance().setCategory(
            .playAndRecord, mode: .default,
            options: [.duckOthers, .defaultToSpeaker, .allowBluetoothA2DP])
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.5
        // The Morphe register (Lucas 2026-08-28): a measured British
        // male — the Jarvis voice. Slightly lowered pitch keeps it in
        // the chest without sounding processed.
        utterance.voice = Self.morpheVoice
        utterance.pitchMultiplier = 0.92
        synthesizer.speak(utterance)
        // Watchdog (audit 12, P2-8): if the utterance never finishes, the
        // glow must not stay lit and the mic must come back.
        speakingWatchdog?.invalidate()
        let ceiling = max(4.0, Double(text.count) / 10.0)
        let watchdog = Timer(timeInterval: ceiling, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self, self.state == .speaking else { return }
                self.synthesizer.stopSpeaking(at: .immediate)
                self.state = .passive
                self.beginListening()
            }
        }
        speakingWatchdog = watchdog
        RunLoop.main.add(watchdog, forMode: .common)
    }

    private func tearDownRecognition() {
        commandTimer?.invalidate()
        commandTimer = nil
        // UNCONDITIONAL removal (audit 13, P0): an interruption stops the
        // engine before we get here, so gating on isRunning left the tap
        // installed — and the next installTap on the same bus is a hard
        // crash. Both calls are safe no-ops when nothing is running.
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
    }

    private func beginListening() {
        guard state == .passive else { return }
        tearDownRecognition()
        liveTranscript = ""
        // No recognizer for this locale at all — that's permanent, not a
        // glitch; say so instead of six pointless restarts (audit 13).
        guard let recognizer = SFSpeechRecognizer() else {
            failPermanently("Hey Morphe isn't available for your language on this iPhone.")
            return
        }
        // The wake phrases are English — a non-English recognizer would
        // burn mic and battery on a wake that can never match (audit 13).
        guard recognizer.locale.language.languageCode == .english else {
            failPermanently("Hey Morphe currently understands English only — staying off so it doesn't listen for a phrase it can't hear.")
            return
        }
        guard recognizer.isAvailable else {
            scheduleRestart()
            return
        }
        // On-device or OFF (audit 12, P0-4): the settings toggle promises
        // speech stays on this iPhone — without on-device support we
        // refuse rather than stream continuous audio to servers.
        guard recognizer.supportsOnDeviceRecognition else {
            failPermanently("Hey Morphe needs on-device speech, which isn't available for your language on this iPhone — staying off rather than sending audio to servers.")
            return
        }
        self.recognizer = recognizer

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        // "Morphe" is not in the recognizer's vocabulary — without this
        // bias it transcribes "Hey Murphy" and the wake never fires for
        // the name actually said (audit 14).
        request.contextualStrings = Self.contextualVocabulary
        self.request = request
        SoundEffects.externalAudioOwner = true

        let session = AVAudioSession.sharedInstance()
        do {
            // .mixWithOthers, not .duckOthers (audit 13, P1): merely
            // WAITING for a wake word must not quiet the user's playlist
            // for the whole workout. speak() ducks for its own duration.
            try session.setCategory(.playAndRecord, mode: .default,
                                    options: [.mixWithOthers, .defaultToSpeaker, .allowBluetoothA2DP])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            let node = audioEngine.inputNode
            let format = node.outputFormat(forBus: 0)
            node.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                request.append(buffer)
            }
            audioEngine.prepare()
            try audioEngine.start()
            // NOT the place to reset restartAttempts (audit 13, P1): the
            // engine starting proves nothing about the recognizer — a
            // task-level failure loop would reset its own backoff every
            // pass. scheduleRestart resets it after a demonstrably
            // healthy listen instead.
            listenStartedAt = Date()
        } catch {
            scheduleRestart()
            return
        }

        // Identity-checked callback (audit 13, P2): a cancelled task's
        // error can arrive after a fresh listener is already up — it must
        // not tear down its replacement.
        var startedTask: SFSpeechRecognitionTask?
        startedTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self, self.task === startedTask else { return }
                self.handle(result: result, error: error)
            }
        }
        task = startedTask
    }

    /// A condition that will not fix itself: state off, session handed
    /// back, honest line surfaced (audit 13 — the refusal paths used to
    /// leave the ducked session active).
    private func failPermanently(_ message: String) {
        standDown()
        onFailure?(message)
    }

    /// Same teardown, recoverable signal (audit 14): the engine goes quiet
    /// but the feature stays enabled — start() can re-arm it later.
    private func pauseTransiently(_ message: String) {
        standDown()
        onTransientPause?(message)
    }

    private func standDown() {
        state = .off
        followUpDeadline = nil
        activeIsFollowUp = false
        directCaptureSession = false
        followUpCaptureStart = nil
        tearDownRecognition()
        SoundEffects.externalAudioOwner = false
        let session = AVAudioSession.sharedInstance()
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
        try? session.setCategory(.ambient, options: [.mixWithOthers])
    }

    private func handle(result: SFSpeechRecognitionResult?, error: Error?) {
        guard state == .passive || state == .active else { return }
        if let result {
            let text = result.bestTranscription.formattedString
            switch state {
            case .passive:
                if let command = Self.commandAfterWake(in: text) {
                    state = .active
                    activeIsFollowUp = false
                    liveTranscript = command
                    onWake?()
                    // A longer first window (audit 14): the user just said
                    // the name — give them a breath before the command.
                    armCommandTimer(after: command.isEmpty ? 2.5 : 1.4)
                } else if let deadline = followUpDeadline, Date() < deadline,
                          !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // Follow-up window (rebuild 2026-08): the breath after
                    // Morphe speaks accepts a bare command — "next
                    // exercise" right after an answer, no re-wake. The
                    // store routes these doors-only, so ambient chatter
                    // costs nothing.
                    state = .active
                    activeIsFollowUp = true
                    followUpCaptureStart = Date()
                    liveTranscript = text
                    armCommandTimer(after: 1.4)
                }
            case .active where activeIsFollowUp:
                // A re-wake inside the window must WIN (audit 17, P1):
                // partials arrive word-by-word, so "hey" enters follow-up
                // capture before the full phrase can possibly match —
                // promote to a normal wake the moment it does, chime and
                // all, or the user says the name and gets played dead.
                if let command = Self.commandAfterWake(in: text) {
                    activeIsFollowUp = false
                    followUpCaptureStart = nil
                    liveTranscript = command
                    onWake?()
                    armCommandTimer(after: command.isEmpty ? 2.5 : 1.4)
                } else if let began = followUpCaptureStart,
                          Date().timeIntervalSince(began) > 8
                            || text.split(separator: " ").count > 12 {
                    // Ceiling (audit 17, P1): continuous background speech
                    // re-arms the settle timer forever — the wake path got
                    // this fix in audit 14; the follow-up path needs its
                    // own. Collapse silently and go back to scanning.
                    commandTimer?.invalidate()
                    commandTimer = nil
                    liveTranscript = ""
                    activeIsFollowUp = false
                    followUpCaptureStart = nil
                    state = .passive
                } else if text != liveTranscript {
                    liveTranscript = text
                    armCommandTimer(after: 1.4)
                }
            case .active:
                // Re-locate the wake phrase EVERY partial (audit 12, P1-9):
                // the recognizer retro-corrects earlier words, so a frozen
                // character offset drifted and sliced commands mid-word.
                // Re-arm ONLY when the transcript actually changed (audit
                // 14): gym noise emits a partial stream that re-armed the
                // timer forever, and the command never fired.
                if let command = Self.commandAfterWake(in: text) {
                    if command != liveTranscript {
                        liveTranscript = command
                        // A retraction back to the bare wake re-earns the
                        // breath window (audit 14, P3).
                        armCommandTimer(after: command.isEmpty ? 2.5 : 1.4)
                    }
                } else {
                    // The recognizer retro-corrected the wake phrase AWAY —
                    // it heard the gym TV, not the user. Without this the
                    // armed timer fired the stale fragment as a phantom
                    // command (audit 14, P2).
                    commandTimer?.invalidate()
                    commandTimer = nil
                    liveTranscript = ""
                    state = .passive
                }
            default:
                break
            }
            if result.isFinal {
                // The recognizer capped the stream (~1 min) — fire what we
                // have or go back to scanning.
                state == .active ? fireCommand() : scheduleRestart()
                return
            }
        }
        if error != nil {
            state == .active ? fireCommand() : scheduleRestart()
        }
    }

    /// Finds the wake phrase in the CURRENT hypothesis and returns what
    /// follows it — nil when no wake phrase is present. Internal so the
    /// mis-hearing table is test-covered (audit 14: the old substring scan
    /// matched "hey murph" inside "hey murphy" and prefixed every command
    /// with the leftover "y").
    static func commandAfterWake(in text: String) -> String? {
        let range = NSRange(text.startIndex..., in: text)
        guard let match = wakePattern.firstMatch(in: text, range: range),
              let matchRange = Range(match.range, in: text) else { return nil }
        var command = String(text[matchRange.upperBound...]).trimmingCharacters(
            in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
        // "Hey Morphe hey Morphe open train" — an echoing gym or a stutter
        // repeats the wake; strip every leading repeat (audit 14, P3).
        while let stripped = Self.commandAfterWake(in: command) {
            command = stripped
        }
        return command
    }

    private func armCommandTimer(after interval: TimeInterval) {
        commandTimer?.invalidate()
        // .common mode (audit 12, P2-7): a .default-mode timer pauses
        // while the user scrolls, so commands never fired mid-scroll.
        let timer = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            DispatchQueue.main.async { self?.fireCommand() }
        }
        commandTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    /// Lock-screen mic entry: listening is armed, jump straight to
    /// active capture — no wake phrase, chime and all. Returns false when
    /// the engine isn't ready yet (caller retries).
    func enterActiveCapture() -> Bool {
        guard state == .passive else { return false }
        state = .active
        activeIsFollowUp = true       // whole-stream capture machinery…
        directCaptureSession = true   // …with full routing on fire
        followUpCaptureStart = Date()
        liveTranscript = ""
        onWake?()
        armCommandTimer(after: 2.5)
        return true
    }

    private func fireCommand() {
        guard state == .active else { return }
        let command = liveTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        let wasFollowUp = activeIsFollowUp && !directCaptureSession
        directCaptureSession = false
        activeIsFollowUp = false
        liveTranscript = ""
        state = .passive
        if command.isEmpty || Self.isCancelPhrase(command) {
            // Woke then silence, or an explicit retraction ("never mind")
            // — back to scanning, no charge, no spoken reply (a misfire
            // must cost nothing: rebuild 2026-08).
            beginListening()
            return
        }
        tearDownRecognition()
        onCommand?(command, wasFollowUp)
    }

    /// "Hey Morphe… never mind." A retraction collapses the capture
    /// silently instead of routing a phantom command.
    static func isCancelPhrase(_ text: String) -> Bool {
        let cleaned = text.lowercased()
            .trimmingCharacters(in: .punctuationCharacters.union(.whitespaces))
        // No bare "stop" (audit 17, P2): mid-rest, "Hey Morphe, stop" is
        // a real ask — swallowing it silently left the timer running.
        return ["never mind", "nevermind", "cancel", "cancel that",
                "forget it", "nothing", "no thanks"].contains(cleaned)
    }

    private func scheduleRestart() {
        guard state == .passive || state == .active else { return }
        state = .passive
        tearDownRecognition()
        // A listen pass that survived 30s was healthy — its end is the
        // recognizer's routine ~1min stream cap, not a failure loop. Only
        // rapid-fire failures may climb toward the ceiling (audit 13, P1).
        if let began = listenStartedAt, Date().timeIntervalSince(began) > 30 {
            restartAttempts = 0
        }
        listenStartedAt = nil
        restartAttempts += 1
        // Exponential backoff with a ceiling (audit 12, P1-4): a dead
        // recognizer must not become a permanent 0.6s battery drain.
        guard restartAttempts <= 6 else {
            // Recoverable (audit 14): nothing about the device changed, so
            // this must NOT flip the toggle off — that made one bad minute
            // kill the feature until the user found the switch again.
            pauseTransiently("Hey Morphe hit a snag — it'll keep trying.")
            return
        }
        let delay = min(0.6 * pow(2, Double(restartAttempts - 1)), 20)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.state == .passive else { return }
            self.beginListening()
        }
    }

    // MARK: AVSpeechSynthesizerDelegate

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            guard self.state == .speaking else { return }
            // The answer just landed — hold the door open for a follow-up
            // command with no re-wake (rebuild 2026-08).
            self.followUpDeadline = Date().addingTimeInterval(6)
            self.state = .passive
            self.beginListening()
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            guard self.state == .speaking else { return }
            self.state = .passive
            self.beginListening()
        }
    }
}

/// Live speech-to-text: streams partial transcriptions into the composer as
/// the user talks. On-device where the hardware supports it, so gym-floor
/// dead zones don't kill dictation.
@Observable
final class DictationEngine: NSObject {
    private(set) var isRecording = false
    /// One-line status for the composer ("Listening…", permission help). Nil
    /// when there is nothing worth saying.
    private(set) var notice: String?

    private let audioEngine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    /// Starts dictation, appending to `baseText`. Each partial result calls
    /// `onText` with the full combined string.
    /// Bumped by stop(): the permission chain can't be cancelled at the
    /// system level, so a late callback must find its session superseded
    /// rather than start a hot mic under an idle UI (audit 14, P1 — rapid
    /// mic double-tap, or a timeout while the permission dialog was up).
    private var startToken = 0

    func start(baseText: String, onText: @escaping (String) -> Void) {
        startToken += 1
        let token = startToken
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                guard status == .authorized else {
                    self?.notice = "Enable Speech Recognition for Morphe in Settings to dictate."
                    return
                }
                AVAudioApplication.requestRecordPermission { granted in
                    DispatchQueue.main.async {
                        guard granted else {
                            self?.notice = "Enable the Microphone for Morphe in Settings to dictate."
                            return
                        }
                        guard let self, token == self.startToken else { return }
                        self.beginRecognition(baseText: baseText, onText: onText)
                    }
                }
            }
        }
    }

    private func beginRecognition(baseText: String, onText: @escaping (String) -> Void) {
        tearDown()

        guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else {
            notice = "Dictation isn't available right now."
            return
        }
        self.recognizer = recognizer
        // One mic owner at a time (audit 12, P0-3; rewired audit 13): pause
        // the wake engine HERE — after the guards, before the session grab —
        // not in start() (a denied permission left it paused) and never via
        // stop() (which used to pause-then-resume in the same breath).
        HeyMorpheEngine.shared.pauseForExternalAudio()
        // Reward dings must not flip the category under the live tap
        // (audit 12, P0-2 — was fixed for the wake engine only).
        SoundEffects.externalAudioOwner = true

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        self.request = request

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            let inputNode = audioEngine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                request.append(buffer)
            }
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            // stop() first — its teardown clears notice, so the message
            // must land after it (this ordering was silently wrong before).
            stop()
            notice = "Couldn't start the microphone."
            return
        }

        isRecording = true
        notice = "Listening… tap the mic to stop."

        let prefix = baseText.trimmingCharacters(in: .whitespacesAndNewlines)
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            DispatchQueue.main.async {
                if let result {
                    let spoken = result.bestTranscription.formattedString
                    onText(prefix.isEmpty ? spoken : "\(prefix) \(spoken)")
                }
                if error != nil || (result?.isFinal ?? false) {
                    self?.stop()
                }
            }
        }
    }

    func stop() {
        // Supersede any permission chain still in flight (audit 14, P1).
        startToken += 1
        tearDown()
        // Hand the audio session back to the reward sounds' ambient setup,
        // then let Hey Morphe resume if it was the one we paused.
        SoundEffects.externalAudioOwner = false
        // Deactivate BEFORE the category reset (audit 16, P2): duckOthers
        // un-ducks the other app's audio on deactivation, not on category
        // change — without this a mid-music borrow left the music quiet.
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        HeyMorpheEngine.shared.resumeAfterExternalAudio()
    }

    /// Teardown without the resume side effect — beginRecognition resets
    /// itself with this so starting dictation can't bounce the wake engine
    /// (audit 13: stop()'s resume used to fire BEFORE our tap installed).
    private func tearDown() {
        // Unconditional for the same reason as the wake engine's teardown
        // (audit 13, P0): a stale tap on the shared input bus is a crash
        // at the next installTap.
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        isRecording = false
        notice = nil
    }
}

private struct NetworkProfilePreviewSheet: View {
    @Environment(MorpheAppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var showBooking = false

    let profile: NetworkProfilePreview

    /// Anyone can book a listed coach profile (not another athlete, and
    /// not themselves).
    private var canBookThisCoach: Bool {
        profile.role == .coach
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 14) {
                            Text(profile.avatar)
                                .font(.system(.largeTitle))
                                .frame(width: 62, height: 62)
                                .background(
                                    RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                                        .fill(MorpheTheme.panelStrong)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                                                .stroke(MorpheTheme.stroke, lineWidth: 1)
                                        )
                                )

                            VStack(alignment: .leading, spacing: 4) {
                                Text(profile.name)
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(MorpheTheme.textPrimary)
                                Text("@\(profile.handle)")
                                    .font(.subheadline)
                                    .foregroundStyle(MorpheTheme.textSecondary)
                                Text(profile.headline)
                                    .font(.subheadline)
                                    .foregroundStyle(MorpheTheme.textPrimary)
                            }
                        }

                        HStack(spacing: 10) {
                            StatusBadge(text: profile.role == .coach ? "Coach" : "Athlete", color: MorpheTheme.accent)
                            StatusBadge(text: profile.rank, color: MorpheTheme.accentAlt)
                        }

                        Text(profile.mutualContext)
                            .font(.subheadline)
                            .foregroundStyle(MorpheTheme.textSecondary)

                        WrapStack(spacing: 8) {
                            ForEach(profile.featuredTags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(MorpheTheme.textPrimary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: MorpheTheme.chipRadius, style: .continuous)
                                            .stroke(MorpheTheme.stroke, lineWidth: 1)
                                    )
                            }
                        }
                    }
                }

                if canBookThisCoach {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Train with \(profile.name)")
                                .font(.headline)
                                .foregroundStyle(MorpheTheme.textPrimary)
                            Text("Book a 1-on-1 session and work directly with this coach.")
                                .font(.subheadline)
                                .foregroundStyle(MorpheTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Button {
                                showBooking = true
                            } label: {
                                Label("Book", systemImage: "calendar.badge.plus")
                            }
                            .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                            .accessibilityLabel("Book a session with this coach")
                        }
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick Actions")
                            .font(.headline)
                            .foregroundStyle(MorpheTheme.textPrimary)

                        HStack(spacing: 10) {
                            Button(primaryActionTitle) {
                                handlePrimaryAction()
                                dismissProfile()
                            }
                            .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))

                            // Connect only renders when a real suggestion
                            // backs it — the fallback toasted a connection
                            // that never happened (audit 6, P2-11).
                            if let suggestion = store.networkSuggestions.first(where: { $0.name == profile.name }) {
                                Button("Connect") {
                                    store.connectToNetworkSuggestion(suggestion)
                                    dismissProfile()
                                }
                                .buttonStyle(SecondaryCTAButtonStyle())
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismissProfile()
                }
                .foregroundStyle(MorpheTheme.textPrimary)
            }
        }
        .sheet(isPresented: $showBooking) {
            CoachBookingSheet(coachName: profile.name)
        }
    }

    private func dismissProfile() {
        store.closeNetworkProfile()
        dismiss()
    }

    private var primaryActionTitle: String {
        profile.role == .coach ? "Open Support" : "Open Network"
    }

    private func handlePrimaryAction() {

        if profile.role == .coach {
            store.openCommunity(.contact)
        } else {
            store.openCommunity(FeatureFlags.socialFeedEnabled ? .forYou : .contact)
        }
    }
}

private enum UniversalSearchCategory: String, CaseIterable, Identifiable {
    // Posts retired with the social cut (audit 5, P2): the segment
    // searched a demo array that real accounts clear, and its result rows
    // routed to surfaces that no longer show posts.
    case accounts = "Accounts"
    case plans = "Plans"
    case library = "Library"

    var id: String { rawValue }
}

private struct UniversalSearchSheet: View {
    @Environment(MorpheAppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var category: UniversalSearchCategory = .accounts
    @State private var searchDebounce: Task<Void, Never>?
    @FocusState private var searchFocused: Bool

    private var normalizedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var filteredSuggestions: [NetworkConnectionSuggestion] {
        let suggestions = store.networkSuggestions.filter { suggestion in
            normalizedQuery.isEmpty ||
            suggestion.name.lowercased().contains(normalizedQuery) ||
            suggestion.headline.lowercased().contains(normalizedQuery) ||
            suggestion.mutualContext.lowercased().contains(normalizedQuery)
        }

        return Array(suggestions.prefix(6))
    }

    private var filteredWorkouts: [WorkoutTemplate] {
        let workouts = store.workoutTemplates.filter { workout in
            normalizedQuery.isEmpty ||
            workout.name.lowercased().contains(normalizedQuery) ||
            workout.goal.lowercased().contains(normalizedQuery) ||
            workout.sport.rawValue.lowercased().contains(normalizedQuery)
        }

        return Array(workouts.prefix(8))
    }

    private var filteredExercises: [ExerciseReference] {
        let exercises = store.exerciseDatabase.filter { exercise in
            normalizedQuery.isEmpty ||
            exercise.name.lowercased().contains(normalizedQuery) ||
            exercise.musclesWorked.lowercased().contains(normalizedQuery) ||
            exercise.whyThisMatters.lowercased().contains(normalizedQuery)
        }

        return Array(exercises.prefix(8))
    }

    var body: some View {
        // One scroll owner per page (audit 13, P1): the pager fills the
        // sheet and each page scrolls itself — the old shape (a 420pt
        // pager inside an outer ScrollView) gave two competing vertical
        // scroll regions and buried results under the keyboard on an SE.
        // Same grammar as the Learn pager.
        VStack(alignment: .leading, spacing: 16) {
                SectionTitleView(
                    title: "Search",
                    subtitle: "Accounts, workouts, and exercises without leaving the flow.",
                    titleSize: 16
                )

                TextField("Search accounts, workouts, exercises...", text: $query)
                    .textFieldStyle(MorpheFieldStyle())
                    .focused($searchFocused)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    // Debounced remote lookup (Apple-pattern Task-cancel):
                    // one directory query ~350ms after typing stops, never
                    // one per keystroke.
                    .onChange(of: query) { _, newValue in
                        searchDebounce?.cancel()
                        searchDebounce = Task {
                            try? await Task.sleep(nanoseconds: 350_000_000)
                            guard !Task.isCancelled else { return }
                            await store.searchAthletes(query: newValue)
                        }
                    }

                Picker("Search Category", selection: $category) {
                    ForEach(UniversalSearchCategory.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)

                // Swipe between the categories (Lucas 2026-08-18) — same
                // pager grammar as Train and Learn; the picker stays synced
                // through the shared selection.
                TabView(selection: $category) {
                    ScrollView(showsIndicators: false) {
                        accountsResults.padding(.bottom, 40)
                    }
                    .tag(UniversalSearchCategory.accounts)
                    ScrollView(showsIndicators: false) {
                        plansResults.padding(.bottom, 40)
                    }
                    .tag(UniversalSearchCategory.plans)
                    ScrollView(showsIndicators: false) {
                        libraryResults.padding(.bottom, 40)
                    }
                    .tag(UniversalSearchCategory.library)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    store.closeUniversalSearch()
                    dismiss()
                }
                .foregroundStyle(MorpheTheme.textPrimary)
            }
        }
    }

    @ViewBuilder
    private var accountsResults: some View {
        // REAL accounts (the username directory) — this tab used to show
        // only demo "recommended connections" while searchAthletes sat
        // wired to nothing. Debounced upstream; rows follow in place.
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Accounts")
                    .font(.headline)
                    .foregroundStyle(MorpheTheme.textPrimary)

                if normalizedQuery.count < 2 {
                    Text("Type at least two characters to search @usernames.")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textMuted)
                } else if store.athleteSearchFailed {
                    // Honest offline state (audit 13, P2): "no accounts
                    // match" was a false claim when the query never
                    // reached the directory. Same shape as the board's
                    // failed + Retry.
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Couldn't reach the account directory.")
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textMuted)
                        Button("Retry") {
                            Task { await store.searchAthletes(query: query) }
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MorpheTheme.accentText)
                    }
                } else if store.athleteSearchResults.isEmpty {
                    Text("No accounts match \"\(normalizedQuery)\" yet.")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textMuted)
                } else {
                    ForEach(store.athleteSearchResults) { hit in
                        HStack(spacing: 12) {
                            Text("@\(hit.username)")
                                .font(.subheadline.weight(.semibold).monospaced())
                                .foregroundStyle(MorpheTheme.textPrimary)
                            Spacer()
                            // Follow only exists where a feed can show
                            // it (post-cut audit P1-4) — while the feed
                            // is dark, the door is Message, not a write
                            // into an invisible graph.
                            if FeatureFlags.socialFeedEnabled {
                                Button(store.isFollowing(hit.uid) ? "Following" : "Follow") {
                                    store.toggleFollow(uid: hit.uid, name: hit.username)
                                }
                                .buttonStyle(FilterChipStyle(
                                    isSelected: store.isFollowing(hit.uid),
                                    selectedColor: MorpheTheme.accent))
                                .accessibilityLabel(store.isFollowing(hit.uid)
                                    ? "Unfollow \(hit.username)" : "Follow \(hit.username)")
                            } else {
                                // …and the Message door has to actually
                                // exist (audit 5, P1-3: a found account
                                // was a dead end).
                                Button("Message") {
                                    let uid = hit.uid
                                    let username = hit.username
                                    store.closeUniversalSearch()
                                    dismiss()
                                    Task {
                                        if await store.startDirectChat(with: uid, name: username) {
                                            store.openCommunity(.contact)
                                        }
                                    }
                                }
                                .buttonStyle(FilterChipStyle(isSelected: false))
                                .accessibilityLabel("Message \(hit.username)")
                            }
                        }
                        .frame(minHeight: 44)
                    }
                }

                if FeatureFlags.multiUserEnabled {
                    ForEach(filteredSuggestions) { suggestion in
                        SearchResultRow(
                            title: suggestion.name,
                            subtitle: suggestion.headline,
                            detail: suggestion.mutualContext
                        ) {
                            store.openNetworkProfile(for: suggestion)
                            store.closeUniversalSearch()
                            dismiss()
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var plansResults: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Workout Plans")
                    .font(.headline)
                    .foregroundStyle(MorpheTheme.textPrimary)

                ForEach(filteredWorkouts) { workout in
                    SearchResultRow(
                        title: workout.name,
                        subtitle: "\(workout.sport.rawValue) • \(workout.goal)",
                        detail: "\(workout.durationMinutes) min • \(workout.difficulty.rawValue)"
                    ) {
                        // Dismiss BEFORE queuing (audit 9, P2): the gate
                        // dialog is hosted at the root, under this sheet.
                        store.closeUniversalSearch()
                        dismiss()
                        store.openWorkoutTemplate(workout)
                    }
                }

            }
        }
    }

    @ViewBuilder
    private var libraryResults: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Exercise + Drill Library")
                    .font(.headline)
                    .foregroundStyle(MorpheTheme.textPrimary)

                ForEach(filteredExercises) { exercise in
                    SearchResultRow(
                        title: exercise.name,
                        subtitle: exercise.musclesWorked,
                        detail: exercise.whyThisMatters
                    ) {
                        store.openMore(.library)
                        store.selectedExercise = exercise
                        store.closeUniversalSearch()
                        dismiss()
                    }
                }

            }
        }
    }

}

private struct QuickAddSheet: View {
    @Environment(MorpheAppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var quickNote = ""

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                SectionTitleView(
                    title: "Quick Add",
                    subtitle: "Log the moment, ask for help, or keep momentum moving."
                )

                QuickAddGridCard(items: [
                    QuickAddItem(
                        title: store.hasCompletedWorkoutFlow
                            ? "Finish in Train"
                            : (store.isWorkoutSessionActive
                                ? "Resume Workout"
                                : (store.isWorkoutLoggedToday ? "New Workout" : "Open Workout")),
                        subtitle: store.hasCompletedWorkoutFlow
                            ? "Your session is waiting to be logged"
                            : (store.isWorkoutSessionActive
                                ? "Jump back into Train"
                                : (store.isWorkoutLoggedToday ? "Today's done — browse Discover" : "Start today's plan in Train")),
                        systemImage: store.hasCompletedWorkoutFlow
                            ? "checkmark.circle.fill"
                            : (store.isWorkoutLoggedToday && !store.isWorkoutSessionActive ? "square.grid.2x2.fill" : "figure.run")
                    ) {
                        if store.hasCompletedWorkoutFlow {
                            // ONE canonical Log button (audit E8): Train's
                            // review flow owns the commit — this door
                            // walks there instead of triple-wiring it.
                            store.selectedClientTab = .train
                        } else if store.isWorkoutSessionActive {
                            // Resume = return to the live console. The old
                            // path restarted the session and wiped every
                            // logged set.
                            store.selectedClientTab = .train
                        } else if store.isWorkoutLoggedToday {
                            // Today's workout is already in the books —
                            // offer something new instead of a re-run.
                            store.showDiscoverTab()
                        } else {
                            // Dismiss FIRST (audit 9, P2): the session-
                            // work gate dialog is hosted at the root,
                            // under this sheet.
                            dismissQuickAdd()
                            store.startTodayWorkout()
                            return
                        }
                        dismissQuickAdd()
                    },
                    // Named for where it actually lands (audit E9):
                    // "Browse" implied Discover; this opens the library.
                    QuickAddItem(title: "Exercise Library", subtitle: "Form guides by muscle group", systemImage: "books.vertical.fill") {
                        // openMore selects the library panel — setting the
                        // tab alone landed on whatever panel was last open.
                        store.openMore(.library)
                        dismissQuickAdd()
                    },
                    QuickAddItem(title: "Join a Board", subtitle: "Face the weekly leaderboard", systemImage: "trophy.fill") {
                        // The BOARD pane owns the opt-in flow — this is
                        // the door, not a silent join.
                        store.openCommunity(.board)
                        dismissQuickAdd()
                    },
                    QuickAddItem(title: "Ask Morphe", subtitle: "Quick tips and answers", systemImage: "sparkles") {
                        // Two sheets can't co-present: queue the AI
                        // cover, dismiss this one, and the sheet's
                        // onDismiss opens it — no guessed delay.
                        store.pendingAIAgentOpen = true
                        dismissQuickAdd()
                    }
                ])

                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick Note")
                            .font(.headline)
                            .foregroundStyle(MorpheTheme.textPrimary)
                        // Honest copy: notes save to YOUR list (nothing is
                        // "attached to an athlete" — that claim was false),
                        // and an empty save no longer invents canned text.
                        Text("Capture how you feel, what worked, or what to note for later.")
                            .foregroundStyle(MorpheTheme.textSecondary)

                        TextField("Type a quick note...", text: $quickNote)
                            .textFieldStyle(MorpheFieldStyle())

                        Button("Save Note") {
                            store.saveQuickNote(quickNote)
                            quickNote = ""
                            dismissQuickAdd()
                        }
                        .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                        .disabled(quickNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                if !store.quickCaptureNotes.isEmpty {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recent Notes")
                                .font(.headline)
                                .foregroundStyle(MorpheTheme.textPrimary)

                            ForEach(Array(store.quickCaptureNotes.prefix(3)), id: \.self) { note in
                                Text("• \(note)")
                                    .foregroundStyle(MorpheTheme.textPrimary)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismissQuickAdd()
                }
                .foregroundStyle(MorpheTheme.textPrimary)
            }
        }
    }

    private func dismissQuickAdd() {
        store.closeQuickAdd()
        dismiss()
    }
}

private struct QuickAddItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let systemImage: String
    let action: () -> Void
}

private struct QuickAddGridCard: View {
    let items: [QuickAddItem]

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        GlassCard {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(items) { item in
                    Button(action: item.action) {
                        VStack(alignment: .leading, spacing: 10) {
                            Image(systemName: item.systemImage)
                                .font(.headline)
                                .foregroundStyle(MorpheTheme.accentText)
                            Text(item.title)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(MorpheTheme.textPrimary)
                            Text(item.subtitle)
                                .font(.caption)
                                .foregroundStyle(MorpheTheme.textSecondary)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                                .fill(MorpheTheme.panelInteractive)
                                .overlay(
                                    RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                                        .stroke(MorpheTheme.stroke, lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct SearchResultRow: View {
    let title: String
    let subtitle: String
    let detail: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MorpheTheme.textPrimary)
                Text(subtitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MorpheTheme.accentAlt)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textSecondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

private struct WelcomeExperienceView: View {
    @Environment(MorpheAppStore.self) private var store
    @Environment(\.dismiss) private var dismiss


    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    ProfileBannerView(banner: store.profileShowcase.banner, theme: store.profileShowcase.theme)

                    GlassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 12) {
                                MorpheAvatarView(avatar: store.profileShowcase.avatar, size: 84)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Welcome to Morphe, \(store.clientProfile.name)")
                                        .font(.title3.weight(.bold))
                                        .foregroundStyle(MorpheTheme.textPrimary)
                                    Text("Your profile is live and your first plan is ready.")
                                        .foregroundStyle(MorpheTheme.textSecondary)
                                }
                            }

                            Text(store.clientProfile.welcomeMessage)
                                .font(.headline)
                                .foregroundStyle(MorpheTheme.textPrimary)

                            HStack(spacing: 8) {
                                MetricPill(label: "Primary Sport", value: store.clientProfile.sportMode.rawValue)
                                MetricPill(label: "Primary Goal", value: store.clientProfile.goal)
                            }

                            WrapStack(spacing: 8) {
                                ForEach(store.clientProfile.selectedSports) { sport in
                                    WelcomeTag(text: sport.shortTitle, color: MorpheTheme.color(for: sport))
                                }
                                ForEach(store.clientProfile.selectedTrainingStyles) { style in
                                    WelcomeTag(text: style.rawValue, color: MorpheTheme.warning)
                                }
                                ForEach(store.clientProfile.selectedGoals, id: \.self) { goal in
                                    WelcomeTag(text: goal, color: MorpheTheme.accentAlt)
                                }
                            }
                        }
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("What happens next")
                                .font(.headline)
                                .foregroundStyle(MorpheTheme.textPrimary)
                            // Names the tabs that actually exist, and promises
                            // only what tier 0 shows: one workout to start.
                            Text("Today has your first workout ready. Open Train when you're ready to move — and everything else in Morphe grows from the workouts you log.")
                                .foregroundStyle(MorpheTheme.textSecondary)
                            Text("You can update your name and weight unit anytime from your profile.")
                                .foregroundStyle(MorpheTheme.textPrimary)
                        }
                    }

                    Button("Start Training") {
                        store.dismissWelcomeExperience()
                        dismiss()
                    }
                    .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                }
                .padding(20)
            }
            .background(PremiumBackground())
        }
    }
}

private struct WelcomeTag: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.black)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: MorpheTheme.chipRadius, style: .continuous)
                    .fill(color)
            )
    }
}

/// Hosts the store's session-work gate as a confirmation dialog. Attached
/// ONCE, at the root — sheet-hosted callers dismiss before queuing so the
/// dialog always presents on the surface that's actually visible.
private struct SessionWorkGateDialog: ViewModifier {
    @Environment(MorpheAppStore.self) private var store

    func body(content: Content) -> some View {
        content.confirmationDialog(
            store.pendingWorkoutChange?.title ?? "Replace today's workout?",
            isPresented: Binding(
                get: { store.pendingWorkoutChange != nil },
                set: { if !$0 { store.cancelPendingWorkoutChange() } }
            ),
            titleVisibility: .visible,
            presenting: store.pendingWorkoutChange
        ) { change in
            // `change` is captured by value, so the confirmed action survives
            // the isPresented binding clearing the store's pending slot.
            Button(
                store.isWorkoutSessionActive
                    ? "Discard Session"
                    : "Log Recap & Continue",
                // Only the live-session case destroys anything (audit 9,
                // P0-2): the recap path COMMITS the finished sets before
                // the change runs, so it must not read as destructive.
                role: store.isWorkoutSessionActive ? .destructive : nil
            ) {
                // Through the store's confirm path, never the raw action
                // (audit 8, P0-1): a finished-but-unlogged recap gets
                // committed as a log before the change runs. Calling
                // change.action() directly silently destroyed those sets
                // while the tests exercised the store method the UI skipped.
                store.confirmPendingWorkoutChange(change)
            }
            Button("Keep Current", role: .cancel) {}
        } message: { _ in
            Text(store.isWorkoutSessionActive
                ? "Your workout is in progress — its logged sets will be lost."
                : "Your finished session gets logged first — then the change runs. Nothing is lost.")
        }
    }
}

extension View {
    func sessionWorkGateDialog() -> some View {
        modifier(SessionWorkGateDialog())
    }
}
