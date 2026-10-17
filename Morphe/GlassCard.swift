import SwiftUI

struct AppShell<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

struct ClientLayout<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}


/// Thin L-brackets at the panel corners — the HUD signature. Neutral white so
/// yellow stays reserved for actions and data.
// Internal (not private): the story viewer frames itself with the same
// corner ticks the cards and posters use.
struct HUDCornerTicks: View {
    var arm: CGFloat = 9
    var color: Color = MorpheTheme.stroke

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            Path { path in
                // Top-leading
                path.move(to: CGPoint(x: 0, y: arm)); path.addLine(to: .zero); path.addLine(to: CGPoint(x: arm, y: 0))
                // Top-trailing
                path.move(to: CGPoint(x: w - arm, y: 0)); path.addLine(to: CGPoint(x: w, y: 0)); path.addLine(to: CGPoint(x: w, y: arm))
                // Bottom-trailing
                path.move(to: CGPoint(x: w, y: h - arm)); path.addLine(to: CGPoint(x: w, y: h)); path.addLine(to: CGPoint(x: w - arm, y: h))
                // Bottom-leading
                path.move(to: CGPoint(x: arm, y: h)); path.addLine(to: CGPoint(x: 0, y: h)); path.addLine(to: CGPoint(x: 0, y: h - arm))
            }
            .stroke(color, lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}

/// Card contrast tiers (2026-09): important cards read LOUDER against
/// the field, quiet ones recede. HERO = the page's one moment; QUIET =
/// hints/links/footers; STANDARD = everything else (the default, and
/// pixel-identical to the pre-tier card).
enum CardEmphasis {
    case hero, standard, quiet

    var fill: Color {
        switch self {
        case .hero: return MorpheTheme.panelRaised
        case .standard: return MorpheTheme.panel
        case .quiet: return MorpheTheme.panelQuiet
        }
    }
    var stroke: Color {
        switch self {
        case .hero: return MorpheTheme.stroke
        case .standard: return MorpheTheme.panelStrong
        case .quiet: return MorpheTheme.strokeSubtle
        }
    }
    /// The HUD ticks mark importance — quiet cards drop them.
    var showsCornerTicks: Bool { self != .quiet }
}

private struct PerformancePanelBackground: View {
    var cornerRadius: CGFloat = MorpheTheme.radius
    var emphasis: CardEmphasis = .standard

    var body: some View {
        // Flat telemetry panel: one surface tint, one hairline, corner
        // ticks — tiered by emphasis (contrast tiers 2026-09).
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(emphasis.fill)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(emphasis.stroke, lineWidth: 1)
            )
            .overlay {
                if emphasis.showsCornerTicks { HUDCornerTicks() }
            }
    }
}

struct GlassCard<Content: View>: View {
    let emphasis: CardEmphasis
    let content: Content

    init(_ emphasis: CardEmphasis = .standard, @ViewBuilder content: () -> Content) {
        self.emphasis = emphasis
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(PerformancePanelBackground(emphasis: emphasis))
    }
}

/// The page-top tabs grammar (Discover's FITNESS · EXPLORE, Network's
/// BOARD · CHATS · CALENDAR): equal columns, tracked mono labels, a short
/// accent underline under the active one. One item renders as a plain
/// underlined title (Train). Lucas 2026-10-17.
struct MonoSectionTabs<ID: Hashable>: View {
    let items: [(id: ID, title: String)]
    @Binding var selection: ID

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(items, id: \.id) { item in
                let isActive = selection == item.id
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selection = item.id }
                } label: {
                    VStack(alignment: .center, spacing: 5) {
                        Text(item.title.uppercased())
                            .font(MorpheTheme.microLabel(16))
                            .tracking(1.6)
                            .foregroundStyle(isActive ? MorpheTheme.textPrimary : MorpheTheme.textMuted)
                        Rectangle()
                            .fill(isActive ? MorpheTheme.accent : .clear)
                            .frame(width: 34, height: 3)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .bottom)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title)
                .accessibilityAddTraits(isActive ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
        .frame(maxWidth: .infinity)
    }
}

/// Morphe's line under a page's tabs (Lucas 2026-10-17): the sparkle and
/// one sentence, the same grammar as Today's directive.
/// The three Spartan designs (Lucas 2026-10-17): Activated (eyes lit) is
/// the on/first-command face; Still (half-lit visor) is listening/reading
/// — Morphe speaking, the user reading; Sleeping (dark visor) is
/// thinking/computing — the user speaking after the first command.
enum SpartanFrame: Hashable {
    /// `superActivated` (Lucas 2026-10-17): the electrified helmet, saved
    /// as an asset and ready; not wired to any state yet.
    /// `noPower` (Lucas 2026-10-17): the plain lit helmet in a clear
    /// glass, no ribbons — the intro's resting state before activation.
    case activated, still, sleeping, superActivated, noPower
    var imageName: String {
        switch self {
        case .activated: return "MorpheAIOrbActivated"
        case .noPower: return "MorpheAIOrbNoPower"
        case .superActivated: return "MorpheAIOrbSuperActivated"
        case .still: return "MorpheAIOrbStill"
        case .sleeping: return "MorpheAIOrbSleeping"
        }
    }
}

/// The Spartan waking inside the orb (Lucas 2026-10-17): sleeping fades
/// on, the visor half-lights (still), the eyes light (activated), and it
/// settles on still. Runs once on appear over `duration`; Reduce Motion
/// shows the still frame.
struct SpartanWakeView: View {
    var duration: Double = 1.1
    /// The first wake after TAP TO BEGIN (Lucas 2026-10-17): the super
    /// activated Spartan holds for 2 s in place of the activated beat,
    /// then sleeping for a moment, then it settles on activated (the
    /// design that stays through onboarding). Off: the stage's wake,
    /// sleeping → still → activated → still.
    var superWake: Bool = false
    var onAwake: (() -> Void)? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 0 sleeping · 1 still · 2 activated · 3 still (settled) ·
    /// 4 super activated · 5 sleeping again · 6 activated (settled).
    @State private var wake = 0
    @State private var shown = false

    private var superOn: Bool { wake == 4 }

    var body: some View {
        ZStack {
            Image(SpartanFrame.sleeping.imageName).resizable().interpolation(.high).scaledToFit()
                .opacity(wake == 0 || wake == 5 ? 1 : 0)
            Image(SpartanFrame.still.imageName).resizable().interpolation(.high).scaledToFit()
                .opacity(wake == 1 || wake == 3 ? 1 : 0)
            Image(SpartanFrame.activated.imageName).resizable().interpolation(.high).scaledToFit()
                .opacity(wake == 2 || wake == 6 ? 1 : 0)
                .shadow(color: MorpheTheme.brandBlue.opacity(wake == 2 ? 0.7 : 0), radius: wake == 2 ? 28 : 0)
            if superWake {
                SuperActivatedSpartan(live: superOn && !reduceMotion)
                    .opacity(superOn ? 1 : 0)
                    .shadow(color: MorpheTheme.brandBlue.opacity(superOn ? 0.8 : 0), radius: superOn ? 34 : 0)
            }
        }
        .scaleEffect((wake == 2 || superOn) && !reduceMotion ? 1.04 : 1)
        .opacity(shown ? 1 : 0)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: wake)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.35), value: shown)
        .task {
            if reduceMotion { shown = true; wake = superWake ? 6 : 3; onAwake?(); return }
            shown = true                                   // sleeping fades on
            try? await Task.sleep(for: .milliseconds(Int(duration * 1000 * 0.35)))
            wake = 1                                       // still
            try? await Task.sleep(for: .milliseconds(Int(duration * 1000 * 0.25)))
            if superWake {
                wake = 4                                   // super activated, 2 s (the view fires the jolt)
                try? await Task.sleep(for: .seconds(2))
                wake = 5                                   // sleeping, briefly
                try? await Task.sleep(for: .milliseconds(380))
                wake = 6                                   // activated, and stays
                Haptics.impact(.light)
                try? await Task.sleep(for: .milliseconds(Int(duration * 1000 * 0.15)))
                onAwake?()
                return
            }
            wake = 2                                       // activated
            Haptics.impact(.light)
            try? await Task.sleep(for: .milliseconds(Int(duration * 1000 * 0.25)))
            wake = 3                                       // settles on still
            try? await Task.sleep(for: .milliseconds(Int(duration * 1000 * 0.15)))
            onAwake?()
        }
        .accessibilityHidden(true)
    }
}

/// The super activated Spartan, alive (Lucas 2026-10-17): the helmet
/// moves subtly (a slow bob and breath), the electricity in the helmet
/// and around the orb shimmers and glows, the eyes glow. The art is one
/// picture, so the layers are light passes masked to its regions — eyes
/// at (0.413, 0.565) and (0.600, 0.565) of the crop, helmet centred.
struct SuperActivatedSpartan: View {
    var live: Bool

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            TimelineView(.animation(minimumInterval: 1.0 / 40.0, paused: !live)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                let breath = live ? 1 + 0.012 * sin(t * 2 * .pi / 1.7) : 1
                let bob = live ? CGFloat(sin(t * 2 * .pi / 2.3)) * size * 0.006 : 0
                let pulse = 0.5 + 0.5 * sin(t * 2 * .pi / 1.1)
                let eye = 0.5 + 0.5 * sin(t * 2 * .pi / 0.65 + 0.8)
                let flicker = Double((Int(t * 30) &* 1103515245 &+ 12345) & 0x7fff) / 32767
                let shimmer = max(0, 0.35 + 0.35 * sin(t * 13.0) + 0.3 * sin(t * 29.0) - 0.4 * flicker)
                ZStack {
                    Image(SpartanFrame.superActivated.imageName)
                        .resizable().interpolation(.high).scaledToFit()
                        .scaleEffect(breath)
                        .offset(y: bob)
                    if live {
                        ZStack {
                            // Electricity in the helmet: a flickering shimmer.
                            Ellipse()
                                .fill(Color.white.opacity(0.2 * shimmer))
                                .frame(width: size * 0.34, height: size * 0.5)
                                .blur(radius: size * 0.05)
                                .offset(y: -size * 0.02)
                            // Electricity in the orb: the rim and field glow
                            // in a pulse, offset from the helmet's flicker.
                            Circle()
                                .strokeBorder(Color(red: 0.55, green: 0.8, blue: 1).opacity(0.25 + 0.3 * pulse), lineWidth: size * 0.05)
                                .blur(radius: size * 0.03)
                            Circle()
                                .fill(RadialGradient(colors: [.clear, MorpheTheme.brandBlue.opacity(0.1 + 0.18 * shimmer)], center: .center, startRadius: size * 0.2, endRadius: size * 0.5))
                            // Eyes.
                            ForEach([0.413, 0.600], id: \.self) { ex in
                                Circle()
                                    .fill(Color.white.opacity(0.4 + 0.5 * eye))
                                    .frame(width: size * 0.06, height: size * 0.06)
                                    .blur(radius: size * 0.022)
                                    .position(x: size * ex, y: size * 0.565 + bob)
                            }
                        }
                        .blendMode(.plusLighter)
                        .clipShape(Circle())
                    }
                }
                .frame(width: size, height: size)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // The jolt, every time the design shows (Lucas 2026-10-17).
        .onAppear { if live { Haptics.superActivated() } }
        .onChange(of: live) { _, now in if now { Haptics.superActivated() } }
        .accessibilityHidden(true)
    }
}

struct MorpheDirectiveLine: View {
    @Environment(MorpheAppStore.self) private var store
    let text: String
    /// page.bucket — long-press offers More / Less of this (persona
    /// audit #13); nil for fixed lines.
    var feedbackKey: String? = nil

    var body: some View {
        if !text.isEmpty {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "sparkle")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(MorpheTheme.accentText)
                Text(text)
                    .multilineTextAlignment(.center)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(MorpheTheme.textPrimary)
            .frame(maxWidth: .infinity)
            .contentTransition(.opacity)
            .contextMenu {
                if let feedbackKey {
                    Button("More like this", systemImage: "hand.thumbsup") { store.rateDirective(feedbackKey, more: true) }
                    Button("Less of this", systemImage: "hand.thumbsdown") { store.rateDirective(feedbackKey, more: false) }
                }
            }
            .accessibilityLabel("Morphe: \(text)")
            .accessibilityHint(feedbackKey == nil ? "" : "Long press for more or less of this")
        }
    }
}

struct SectionTitleView: View {
    let title: String
    let subtitle: String
    /// Page-level headers pass 16 to match the Train/Network section tabs;
    /// section headers deeper in a page keep the 14 default.
    var titleSize: CGFloat = 14

    var body: some View {
        // Alive-wave header: centered, symmetrical — the tracked mono title
        // flanked by matched hairline rules, subtitle centered beneath.
        // (The old leading tick + one-sided rule read left-to-right; the
        // whole app now balances around the center line.)
        VStack(alignment: .center, spacing: 6) {
            HStack(spacing: 10) {
                Rectangle()
                    .fill(MorpheTheme.stroke)
                    .frame(height: 1)
                    .frame(maxWidth: .infinity)

                Text(title.uppercased())
                    // microLabel scales with Dynamic Type; the .bold keeps
                    // the section weight the fixed-size version had.
                    .font(MorpheTheme.microLabel(titleSize).weight(.bold))
                    .tracking(2)
                    .foregroundStyle(MorpheTheme.textPrimary)
                    .lineLimit(1)
                    .layoutPriority(1)

                Rectangle()
                    .fill(MorpheTheme.stroke)
                    .frame(height: 1)
                    .frame(maxWidth: .infinity)
            }

            Text(subtitle)
                .font(.footnote.weight(.medium))
                .foregroundStyle(MorpheTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.bottom, 6)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// The "Hey Morphe" edge glow: the Siri-glow pattern in brand gold — a
/// soft breathing border around the whole screen while Morphe listens or
/// answers. Chrome, not content; hidden from hit-testing and VoiceOver.
/// The Jarvis wave (Lucas 2026-09): layered frequency ribbons in the
/// brand gold, breathing while Morphe listens and pulsing while it
/// talks back. `level` is real voice energy — mic RMS while capturing,
/// per-word pulses while speaking — so the motion is the audio, not a
/// looped animation. Reduce Motion renders a calm static ring.
/// Leaf host for the ring: the ONLY view whose body reads voiceLevel,
/// so per-buffer level writes stop invalidating the root shell
/// (audit 22, P1).
/// The Spartan helmet on its own — Morphe's in-app face (Lucas
/// 2026-10-02: the glass tile is the home-screen icon only). ALWAYS the
/// frosted white helmet, lit from behind — never a blue silhouette. The
/// surfaces it sits on darken under it instead (popup scrims, the ring's
/// backing disc on a light field), so the helmet is the same in every
/// appearance.
struct MorpheHelmetMark: View {
    var glowRadius: CGFloat = 10
    /// On the launch field the glow is white; on the app's own surfaces
    /// it is the accent.
    var onBrandField: Bool = false

    var body: some View {
        Image("HelmetMark")
            .resizable()
            .scaledToFit()
            .shadow(color: onBrandField ? Color.white.opacity(0.55) : MorpheTheme.accent.opacity(0.7),
                    radius: glowRadius)
            .accessibilityHidden(true)
    }
}

struct MorpheVoiceRingHost: View {
    @Environment(MorpheAppStore.self) private var store
    var size: CGFloat = 170
    /// Which Spartan shows (Lucas 2026-10-17).
    var frame: SpartanFrame = .still

    var body: some View {
        // Thinking (luxury audit): a tight, steady presence — working,
        // not performing. The orb is the only shape on the stage (Lucas
        // 2026-10-09: "only use the circle/ball/orb").
        let thinking = store.heyMorphe.state == .thinking
        MorpheOrbView(
            level: thinking ? 0.45 : store.heyMorphe.voiceLevel,
            speaking: store.heyMorphe.state == .speaking,
            thinking: thinking,
            frame: frame
        )
        .frame(width: size, height: size)
    }
}

/// The Morphe AI mark, alive (Lucas 2026-10-09: "make it look exactly
/// like this" — the glass bubble with the blue ribbons under the
/// Spartan, Siri's orb as the motion reference). The mark itself is
/// Lucas's image with its black keyed to transparency, so the bubble is
/// real glass: Liquid Glass on iOS 26 (a dark tint keeps the interior
/// deep, as in the image), the material elsewhere. On top, animated
/// ribbons flow at the voice's own pace and a light runs along the rim;
/// the whole bubble breathes with the level. Reduce Motion: one still
/// frame.
struct MorpheOrbView: View {
    /// 0…1 voice energy; the idle breath lives above 0.
    var level: Double
    var speaking: Bool = false
    var thinking: Bool = false
    /// False draws one still frame (buttons, list rows).
    var animates: Bool = true
    /// Which Spartan design shows (Lucas 2026-10-17).
    var frame: SpartanFrame = .activated
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The orb fades on (Lucas 2026-10-16) wherever it is mounted live —
    /// the Hey Morphe stage, the welcome pop-up — instead of appearing.
    @State private var faded = false

    private final class PhaseBox {
        var phase: Double = 0
        var lastTime: Double?
    }
    @State private var phaseBox = PhaseBox()

    private var live: Bool { animates && !reduceMotion }

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            ZStack {
                glass(size)
                bloom(size)
                // The orb without its helmet, then the ribbons, then a glow
                // traced from the helmet's own shape, then the helmet —
                // orb, glow, mask (Lucas 2026-10-10).
                // The finished Spartan orb (Lucas 2026-10-17: one image,
                // helmet baked in). It breathes with the voice as a whole.
                Image(frame.imageName)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(reduceMotion ? 1 : 1 + level * 0.06)
                    .animation(.easeOut(duration: 0.1), value: level)
                    .id(frame)
                innerGlow(size)
                if live { ribbons(size).clipShape(Circle().inset(by: size * 0.045)).opacity(0.5) }
                if live { rimLight(size) }
            }
            // One compositing group: the ribbons' screen blend stays
            // inside the orb instead of bleeding into the page.
            .compositingGroup()
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // A quick fade-on (a fade is also the Reduce Motion-safe entrance).
        .opacity(animates && !faded ? 0 : 1)
        .onAppear {
            guard animates, !faded else { return }
            withAnimation(.easeOut(duration: 0.35)) { faded = true }
        }
        .accessibilityHidden(true)
    }

    // MARK: Layers

    /// The liquid: two translucent glass-blue bodies sloshing under the
    /// helmet in opposite directions, their surface rising with the voice.
    private static func drawLiquid(context: GraphicsContext, size: CGSize, time: Double, level: Double) {
        let w = size.width, h = size.height
        let rise = CGFloat(level) * h * 0.14
        let layers: [(base: CGFloat, amp: CGFloat, waves: Double, dir: Double, phase: Double, top: Color, bottom: Color)] = [
            (0.70, 0.045, 1.2, 1.0, 0.0, glassBlue.opacity(0.42), electric.opacity(0.10)),
            (0.76, 0.035, 1.7, -1.0, 2.1, Color.white.opacity(0.28), electric.opacity(0.06))
        ]
        for layer in layers {
            var path = Path()
            let steps = 64
            let surface = h * layer.base - rise
            path.move(to: CGPoint(x: 0, y: h))
            for step in 0...steps {
                let x = CGFloat(step) / CGFloat(steps) * w
                let theta = Double(x / w) * .pi * 2 * layer.waves + time * layer.dir + layer.phase
                let y = surface + h * layer.amp * (1 + CGFloat(level) * 0.8) * CGFloat(sin(theta) + 0.4 * sin(theta * 2.2 + time * 0.6 * layer.dir))
                path.addLine(to: CGPoint(x: x, y: y))
            }
            path.addLine(to: CGPoint(x: w, y: h))
            path.closeSubpath()
            context.fill(path, with: .linearGradient(
                Gradient(colors: [layer.top, layer.bottom, .clear]),
                startPoint: CGPoint(x: 0, y: surface - h * 0.05), endPoint: CGPoint(x: 0, y: h)))
            // The surface line catches the light.
            var crest = Path()
            for step in 0...steps {
                let x = CGFloat(step) / CGFloat(steps) * w
                let theta = Double(x / w) * .pi * 2 * layer.waves + time * layer.dir + layer.phase
                let y = surface + h * layer.amp * (1 + CGFloat(level) * 0.8) * CGFloat(sin(theta) + 0.4 * sin(theta * 2.2 + time * 0.6 * layer.dir))
                if step == 0 { crest.move(to: CGPoint(x: x, y: y)) } else { crest.addLine(to: CGPoint(x: x, y: y)) }
            }
            context.stroke(crest, with: .color(Color.white.opacity(0.35 + level * 0.3)),
                           style: StrokeStyle(lineWidth: max(0.8, h * 0.006), lineCap: .round))
        }
    }

    // The orb's colors follow the user's accent (Lucas 2026-10-10); only
    // the helmet keeps the image's own colors.
    private static var navy: Color { MorpheTheme.orbColors.deep }
    private static var glassBlue: Color { MorpheTheme.orbColors.glass }
    private static var electric: Color { MorpheTheme.orbColors.electric }

    /// The bubble: real glass with a deep accent tint so the interior
    /// stays as deep as the image on any field (the mark is light on dark).
    @ViewBuilder
    private func glass(_ size: CGFloat) -> some View {
        let tint = Self.navy.opacity(MorpheTheme.isLight ? 0.78 : 0.55)
        if #available(iOS 26.0, *) {
            Color.clear
                .glassEffect(Glass.regular.tint(tint), in: Circle())
        } else {
            Circle().fill(.ultraThinMaterial)
                .overlay(Circle().fill(tint))
        }
    }

    /// Inner blue bloom that swells with the voice (the image's glow).
    private func bloom(_ size: CGFloat) -> some View {
        Circle()
            .fill(RadialGradient(
                colors: [Self.electric.opacity(0.18 + level * 0.32), .clear],
                center: .center, startRadius: 0, endRadius: size * 0.5))
            .animation(.easeOut(duration: 0.12), value: level)
    }

    /// A small glow just inside the rim, brightening a little with the
    /// voice — the glass catching light from within.
    private func innerGlow(_ size: CGFloat) -> some View {
        Circle()
            .strokeBorder(AngularGradient(
                colors: [Self.glassBlue.opacity(0.55), Color.white.opacity(0.35), Self.glassBlue.opacity(0.45),
                         Self.electric.opacity(0.4), Self.glassBlue.opacity(0.55)],
                center: .center, angle: .degrees(20)), lineWidth: size * 0.07)
            .padding(size * 0.03)
            .blur(radius: size * 0.03)
            .opacity(0.5 + level * 0.3)
            .animation(.easeOut(duration: 0.12), value: level)
    }

    /// A light running along the rim — Siri's orb shimmer, slow.
    private func rimLight(_ size: CGFloat) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let angle = Angle.degrees((t * (speaking ? 70 : 28)).truncatingRemainder(dividingBy: 360))
            Circle()
                .strokeBorder(AngularGradient(
                    colors: [.clear, .clear, Color.white.opacity(0.9), Self.glassBlue.opacity(0.6), .clear, .clear],
                    center: .center, angle: angle), lineWidth: max(1.2, size * 0.012))
                .blur(radius: size * 0.004)
                .padding(size * 0.004)
        }
    }

    private func ribbons(_ size: CGFloat) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { context, canvasSize in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let dt = min(max(t - (phaseBox.lastTime ?? t), 0), 0.2)
                phaseBox.lastTime = t
                // Idle breath + the voice's own pace: speech makes the
                // ribbons run, silence lets them drift.
                // Visible at rest, running with the voice: idle drifts at
                // ~1.3 rad/s, full voice runs past 4 (Lucas 2026-10-09:
                // "moves like waves… in sync with the user's voice").
                let speed = (speaking ? 1.5 : 1.0) * (1.1 + level * 3.2)
                phaseBox.phase += dt * speed
                Self.drawRibbons(context: context, size: canvasSize, time: phaseBox.phase, level: level)
            }
        }
        .blendMode(.screen)
    }

    /// Two blue ribbons crossing the lower half of the bubble, each a
    /// soft band, a sharp core, and a dotted trace along its crest — the
    /// image's frequency design, moving.
    private static func drawRibbons(context: GraphicsContext, size: CGSize, time: Double, level: Double) {
        let w = size.width, h = size.height
        drawLiquid(context: context, size: size, time: time, level: level)
        let bands: [(y: CGFloat, amp: CGFloat, waves: Double, phase: Double, width: CGFloat, alpha: Double)] = [
            (0.64, 0.10, 1.4, 0.0, 0.07, 0.75),
            (0.72, 0.07, 1.9, 2.4, 0.05, 0.6)
        ]
        let energy = 0.6 + level * 0.9
        for band in bands {
            var path = Path()
            var crest: [CGPoint] = []
            let steps = 80
            for step in 0...steps {
                let x = CGFloat(step) / CGFloat(steps) * w
                let theta = Double(x / w) * .pi * 2 * band.waves + time + band.phase
                let y = h * band.y + h * band.amp * CGFloat(energy) * CGFloat(sin(theta) + 0.35 * sin(theta * 2.3 - time * 0.7))
                let point = CGPoint(x: x, y: y)
                if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
                if step % 4 == 0 { crest.append(point) }
            }
            let gradient = Gradient(colors: [
                electric.opacity(0), electric.opacity(band.alpha), glassBlue.opacity(band.alpha + 0.2),
                Color.white.opacity(band.alpha + 0.15), electric.opacity(band.alpha), electric.opacity(0)
            ])
            let shading = GraphicsContext.Shading.linearGradient(
                gradient, startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: w, y: 0))
            var soft = context
            soft.addFilter(.blur(radius: h * 0.012))
            soft.stroke(path, with: shading, style: StrokeStyle(lineWidth: h * band.width, lineCap: .round))
            context.stroke(path, with: shading, style: StrokeStyle(lineWidth: max(1, h * 0.008), lineCap: .round))
            for (index, point) in crest.enumerated() {
                let r = max(0.7, h * 0.007) * (index % 2 == 0 ? 1 : 0.7)
                context.fill(Path(ellipseIn: CGRect(x: point.x - r, y: point.y - r - h * band.width * 0.5,
                                                    width: r * 2, height: r * 2)),
                             with: .color(Color(red: 0.8, green: 0.92, blue: 1.0).opacity(0.85)))
            }
        }
    }
}

struct MorpheFrequencyRing: View {
    /// 0…1 voice energy from HeyMorpheEngine.
    var level: Double
    /// Speaking runs the phase faster than listening.
    var speaking: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Phase accumulator (Lucas 2026-09: the frequency moves ONLY when
    /// voice is actually picked up). Each frame advances the wave by
    /// dt × speed × level — silence freezes the ribbons mid-shape;
    /// speech makes them flow at the voice's own energy. A reference
    /// box, not @State: mutating it during render must not re-render.
    private final class PhaseBox {
        var phase: Double = 0
        var lastTime: Double?
    }
    @State private var phaseBox = PhaseBox()

    var body: some View {
        Group {
            if reduceMotion {
                Canvas { context, size in
                    Self.draw(context: context, size: size, time: 0, level: 0.35, speaking: false)
                }
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    Canvas { context, size in
                        let t = timeline.date.timeIntervalSinceReferenceDate
                        let dt = min(max(t - (phaseBox.lastTime ?? t), 0), 0.2)
                        phaseBox.lastTime = t
                        // A whisper of idle drift (0.04) keeps the ring
                        // alive enough to read as ON; real motion is the
                        // voice.
                        let speed = speaking ? 1.7 : 0.9
                        phaseBox.phase += dt * speed * (0.04 + level * 1.8)
                        Self.draw(context: context, size: size, time: phaseBox.phase, level: level, speaking: speaking)
                    }
                }
            }
        }
        // The REAL brand mark sits STILL at the center while the
        // frequency moves around it (Lucas 2026-09). Outside the
        // TimelineView: it never animates.
        .overlay {
            GeometryReader { proxy in
                let side = min(proxy.size.width, proxy.size.height)
                // The helmet alone at the ring's center (Lucas 2026-10-02:
                // no glass tile when the app opens; 2026-10-03: no disc
                // behind it in light mode either — only the ribbons and
                // the helmet, over the popup's darkened page).
                MorpheHelmetMark(glowRadius: side * 0.05)
                    .frame(width: side * 0.42, height: side * 0.42)
                    .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .accessibilityHidden(true)
    }

    /// Three ribbon groups × seven strands, each strand a closed ring
    /// whose radius is modulated by two sine terms — the layered-line
    /// look of a frequency field. Pure function of (time, level).
    private static func draw(context: GraphicsContext, size: CGSize, time: Double, level: Double, speaking: Bool) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let baseRadius = min(size.width, size.height) * 0.34
        let energy = 0.10 + level * 0.55
        // `time` arrives as the voice-driven phase accumulator (or 0 for
        // the static render) — no further speed scaling here.
        let speed = 1.0

        // Soft gold glow behind everything, swelling with the voice.
        let glowRadius = baseRadius * (1.15 + level * 0.35)
        let glowRect = CGRect(x: center.x - glowRadius, y: center.y - glowRadius,
                              width: glowRadius * 2, height: glowRadius * 2)
        let glowTint = MorpheTheme.isLight ? MorpheTheme.accentText : MorpheTheme.accent
        context.fill(Path(ellipseIn: glowRect), with: .radialGradient(
            Gradient(colors: [glowTint.opacity(0.10 + level * 0.14), .clear]),
            center: center, startRadius: 0, endRadius: glowRadius))

        // Light appearance: blue and white ribbons (Lucas 2026-10-03), the
        // same family as dark — the ring lives over a darkened page when a
        // popup is up, so white reads there.
        let groups: [(waves: Double, direction: Double, tint: Color)] = MorpheTheme.isLight
            ? [
                (3, 1, MorpheTheme.accent),
                (4, -1, MorpheTheme.orbColors.glass),
                (5, 1, Color.white.opacity(0.9))
            ]
            : [
                (3, 1, MorpheTheme.accent),
                // Lit, not the deep secondary: #1A3BA3 was 2:1 on the dark
                // canvas and the second ribbon vanished (audit 29).
                (4, -1, MorpheTheme.accentText),
                (5, 1, Color.white.opacity(0.75))
            ]

        for (groupIndex, group) in groups.enumerated() {
            let phase = time * speed * group.direction + Double(groupIndex) * 2.1
            for strand in 0..<7 {
                let strandOffset = Double(strand) * 0.085
                let amplitude = baseRadius * energy * (0.55 + Double(strand) * 0.09)
                var path = Path()
                let steps = 120
                for step in 0...steps {
                    let theta = Double(step) / Double(steps) * 2 * .pi
                    let wobble = sin(theta * group.waves + phase + strandOffset * 4)
                        + 0.45 * sin(theta * (group.waves + 2) - phase * 1.3 + strandOffset * 7)
                    let radius = baseRadius + amplitude * wobble * 0.5
                    let point = CGPoint(x: center.x + cos(theta) * radius,
                                        y: center.y + sin(theta) * radius)
                    if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
                }
                path.closeSubpath()
                var opacity = 0.10 + (1 - Double(strand) / 7.0) * (0.16 + level * 0.14)
                if MorpheTheme.isLight { opacity = min(opacity * 1.8, 0.85) }
                context.stroke(path, with: .color(group.tint.opacity(opacity)), lineWidth: 1)
            }
        }
    }
}


/// Live transcription while Morphe captures a command (rebuild 2026-08):
/// both Siri and ChatGPT show the words as they land — seeing "10 at 135"
/// appear is the trust signal that the mic heard THOSE numbers.
struct VoiceTranscriptPill: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "waveform")
                .font(.caption.weight(.semibold))
                .foregroundStyle(MorpheTheme.accentText)
                .symbolEffect(.variableColor.iterative, options: .repeating)
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MorpheTheme.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(Capsule().stroke(MorpheTheme.stroke, lineWidth: 1))
                // Contact + ambient pair (design wave 2026-10-01) —
                // a single mid blur reads flat and fake.
                .shadow(color: .black.opacity(0.10), radius: 3, y: 2)
                .shadow(color: .black.opacity(0.10), radius: 18, y: 10)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Morphe is hearing: \(text)")
    }
}

/// What Morphe heard and what it answered — floats briefly at the top,
/// then clears itself.
struct VoiceExchangeChip: View {
    let heard: String
    let answer: String

    var body: some View {
        VStack(spacing: 6) {
            Text("\u{201C}\(heard)\u{201D}")
                .font(.caption)
                .foregroundStyle(MorpheTheme.textMuted)
                .lineLimit(2)
            Text(answer)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MorpheTheme.textPrimary)
                .lineLimit(4)
        }
        .multilineTextAlignment(.center)
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                        .stroke(MorpheTheme.stroke, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.10), radius: 3, y: 2)
                .shadow(color: .black.opacity(0.10), radius: 18, y: 10)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Morphe heard: \(heard). Answer: \(answer)")
    }
}

/// The once-ever hello (Apple benchmark A6): one warm word, once per
/// account lifetime — the whole beat is under three seconds and then it
/// never happens again.
struct HelloBeatOverlay: View {
    @Environment(MorpheAppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = false

    var body: some View {
        ZStack {
            MorpheTheme.ink.ignoresSafeArea()
            Text("hello, \(store.greetingName)")
                .font(.system(size: 42, weight: .light, design: .serif))
                .italic()
                .foregroundStyle(MorpheTheme.accentText)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .padding(.horizontal, 32)
                .opacity(visible ? 1 : 0)
                .scaleEffect(visible ? 1 : 0.96)
        }
        .onAppear {
            Haptics.impact(.light)
            withAnimation(.easeOut(duration: reduceMotion ? 0.1 : 0.9)) { visible = true }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_300_000_000)
                withAnimation(.easeIn(duration: 0.5)) { visible = false }
                try? await Task.sleep(nanoseconds: 550_000_000)
                store.showHelloBeat = false
                // NOW the welcome sheet rises (audit 11, P0-1) — but only
                // past the terms gate (audit 12, P2-13): an un-agreed
                // account queues the welcome instead.
                if store.hasAcceptedTerms {
                    store.showWelcomeExperience = true
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hello, \(store.greetingName)")
    }
}

/// Sheets cover the root toast overlay, so any store toast fired from
/// sheet-hosted content was invisible (audit 7, P1-3 — the weight guard
/// was the first fix to depend on one). Sheet hosts apply this so the
/// same toasts surface inside the sheet too.
private struct SheetToastSurface: ViewModifier {
    @Environment(MorpheAppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let toast = store.toastMessage {
                ToastBanner(text: toast)
                    .padding(.top, 16)
                    .transition(reduceMotion
                        ? .opacity
                        : .move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: store.toastMessage)
    }
}

extension View {
    /// Apply to a sheet's root so store toasts stay visible over it.
    func sheetToastSurface() -> some View { modifier(SheetToastSurface()) }
}

/// The app's speaking voice gets a shine (alive wave): a soft accent
/// highlight sweeps across the text on a slow loop, so conversational
/// feedback reads as alive rather than printed. Masked to the content, so
/// it works on any text or glyph. Honors Reduce Motion by rendering
/// nothing extra.
private struct GlimmerModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -0.6

    func body(content: Content) -> some View {
        content.overlay {
            if !reduceMotion {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.42),
                        // accentText, not raw accent (audit 7, P1-2): the
                        // sheen has to survive the light field too.
                        .init(color: MorpheTheme.accentText.opacity(0.85), location: 0.5),
                        .init(color: .clear, location: 0.58)
                    ],
                    startPoint: UnitPoint(x: phase - 0.4, y: 0.5),
                    endPoint: UnitPoint(x: phase + 0.4, y: 0.5)
                )
                .mask(content)
                .allowsHitTesting(false)
                .onAppear {
                    // Re-appear keeps old @State, so a bare withAnimation
                    // would animate 1.6 -> 1.6 and freeze (audit 7, P2-1):
                    // reset first, then start the loop.
                    phase = -0.6
                    // Long cycle, short highlight: the sheen crosses the
                    // text once every few seconds instead of strobing.
                    withAnimation(.linear(duration: 3.4).repeatForever(autoreverses: false)) {
                        phase = 1.6
                    }
                }
            }
        }
    }
}

extension View {
    /// Sweeping accent shine for the app's conversational voice.
    func glimmer() -> some View { modifier(GlimmerModifier()) }
}

/// One-time, dismissible guide line — the app introducing a surface in its
/// own voice. Shows until "Got it", then never again for this profile.
/// Honest by construction: it explains what IS there, it never invents.
struct GuideHint: View {
    @Environment(MorpheAppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    let key: String
    let text: String

    var body: some View {
        let _ = store.guideRefresh
        // Quiet voice hides the hints (persona audit #6).
        if !store.hasSeenGuide(key), store.morpheVoiceLevel != .quiet {
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkle")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(MorpheTheme.accentText)
                    MorpheWordmark(height: 9)
                        .foregroundStyle(MorpheTheme.textMuted)
                }
                Text(text)
                    .font(.footnote)
                    .foregroundStyle(MorpheTheme.textSecondary)
                    .multilineTextAlignment(.center)
                Button("Got it") { store.markGuideSeen(key) }
                    .buttonStyle(.plain)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MorpheTheme.accentText)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                    .accessibilityLabel("Dismiss this tip")
            }
            .frame(maxWidth: .infinity)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                    .fill(MorpheTheme.panel)
                    .overlay(
                        RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                            .stroke(MorpheTheme.strokeSubtle, lineWidth: 1)
                    )
            )
            // Same gentle pop-in as the ask card (Jarvis wave) — once per
            // app session, not on every tab-tap remount (audit 8, P2).
            .scaleEffect(appeared || reduceMotion ? 1 : 0.94)
            .opacity(appeared || reduceMotion ? 1 : 0)
            .onAppear {
                guard !appeared else { return }
                if store.introPlayed("guide.\(key)") {
                    appeared = true
                } else {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.8).delay(0.1)) {
                        appeared = true
                    }
                    store.markIntroPlayed("guide.\(key)")
                }
            }
        }
    }
}

struct MetricPill: View {
    let label: String
    let value: String

    var body: some View {
        // Telemetry readout: accent index bar, mono value — no box.
        HStack(alignment: .top, spacing: 8) {
            Rectangle()
                .fill(MorpheTheme.accent.opacity(0.75))
                .frame(width: 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(label.uppercased())
                    .font(MorpheTheme.microLabel(10))
                    .tracking(1.2)
                    .foregroundStyle(MorpheTheme.textMuted)
                Text(value)
                    .contentTransition(.numericText())
                    .animation(.snappy(duration: 0.25), value: value)
                    .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                    .foregroundStyle(MorpheTheme.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    // Counts roll instead of snapping (feedback pass 2026-09)
                    // — one edit ticks every MetricPill: set count, score,
                    // readiness, energy, this-week.
                    .contentTransition(.numericText())
            }
        }
        .padding(.vertical, 4)
        .padding(.trailing, 8)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(label): \(value)"))
    }
}

struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text.uppercased())
            .font(MorpheTheme.microLabel(10))
            .tracking(1.1)
            // Ink treatment (audit 28, P1): a raw deep accent as text
            // fails on the dark canvas.
            .foregroundStyle(MorpheTheme.asText(color))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: MorpheTheme.chipRadius, style: .continuous)
                    .stroke(color.opacity(0.55), lineWidth: 1)
            )
    }
}

struct ProgressBarView: View {
    let progress: Double
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(MorpheTheme.panelStrong)

                Rectangle()
                    .fill(color)
                    // No phantom sliver at zero — an empty bar means empty.
                    .frame(width: progress <= 0 ? 0 : max(proxy.size.width * progress, 4))
            }
        }
        .frame(height: 5)
        .clipShape(RoundedRectangle(cornerRadius: 1, style: .continuous))
        .animation(.easeInOut(duration: 0.35), value: progress)
        .accessibilityElement()
        .accessibilityValue(Text("\(Int((progress * 100).rounded())) percent"))
    }
}

struct ToastBanner: View {
    let text: String

    var body: some View {
        // Floats over content, so the fill is solid ink — not a surface tint.
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(MorpheTheme.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                    .fill(MorpheTheme.ink.opacity(0.97))
            )
            .overlay(
                RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                    .stroke(MorpheTheme.accent.opacity(0.45), lineWidth: 1)
            )
    }
}

/// The Morphe overlay: the app's persona SPEAKING to the user — greeting,
/// guidance, milestone, encouragement (Lucas 2026-09). Every
/// `showCelebration` routes here, so this one surface carries Morphe's
/// voice consistently. The gold "MORPHE" kicker marks it as the assistant
/// talking, distinct from a plain mechanical toast; the mark animates in
/// (reduceMotion-aware). Two-tier doctrine: Morphe speaks through this;
/// terse mechanical confirmations stay as quiet toasts.
struct CelebrationOverlay: View {
    let moment: CelebrationMoment
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var marked = false

    var body: some View {
        // Floats over scroll content like the toast: solid ink fill + gold
        // hairline (a translucent surface tint read as see-through here).
        HStack(spacing: 12) {
            // Morphe's face on every spoken overlay (bubble redesign
            // 2026-09): the frequency ring replaces the bare SF symbol —
            // the symbol moves inline next to the title, keeping its
            // meaning (star/trophy/flame).
            MorpheFrequencyRing(level: 0.3, speaking: false)
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                MorpheWordmark(height: 10)
                    .foregroundStyle(MorpheTheme.accentText)
                HStack(spacing: 6) {
                    Image(systemName: moment.symbol)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(MorpheTheme.accentText)
                        .symbolEffect(.bounce, value: marked)
                    Text(moment.title)
                        .font(.headline)
                        .foregroundStyle(MorpheTheme.textPrimary)
                }
                Text(moment.detail)
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)
            }

            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                .fill(MorpheTheme.ink.opacity(0.97))
        )
        .overlay(
            RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                .stroke(MorpheTheme.accent.opacity(0.45), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Morphe: \(moment.title). \(spokenDetail)")
        // VoiceOver never heard the moment (audit 25, P2): focus returns
        // to the screen on sheet dismissal and the banner is gone before
        // anyone reaches it — announce it instead.
        .onAppear {
            if !reduceMotion { marked.toggle() }
            AccessibilityNotification.Announcement("\(moment.title). \(spokenDetail)").post()
        }
        // A milestone can overwrite an on-screen "+50 XP" moment without
        // the view leaving the tree, so onAppear won't re-fire — bounce on
        // the moment change too (audit 20 P2).
        .onChange(of: moment.id) {
            if !reduceMotion { marked.toggle() }
            AccessibilityNotification.Announcement("\(moment.title). \(spokenDetail)").post()
        }
    }

    /// "9/10" reads as a date to VoiceOver — say "out of 10".
    private var spokenDetail: String {
        moment.detail.replacingOccurrences(of: "/10", with: " out of 10")
    }
}

/// The ESCALATED celebration: a full-screen stamp for PRs and finished
/// programs. Deliberately no confetti — the moment stays in the HUD
/// language (ink, mono, hairlines) and the share card is one tap away.
/// Everything else keeps the small banner above.
struct RecordStampOverlay: View {
    let moment: RecordStampMoment
    /// Caption for the share sheet (carries the referral handle).
    let caption: String
    /// Fired only on a COMPLETED system share — telemetry hook.
    let onShareCompleted: () -> Void
    let onDismiss: () -> Void

    @State private var sharePayload: ShareCardPayload?

    var body: some View {
        ZStack {
            MorpheTheme.ink.opacity(0.97)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(spacing: 0) {
                Text(moment.kicker)
                    .scaledFont(size: 13, weight: .bold, design: .monospaced)
                    .tracking(3)
                    .foregroundStyle(MorpheTheme.accentText)
                    .padding(.bottom, 16)

                Text(moment.headline)
                    .scaledFont(size: 34, weight: .black)
                    .foregroundStyle(MorpheTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.6)
                    .padding(.bottom, 14)

                Text(moment.valueLine.uppercased())
                    .scaledFont(size: 28, weight: .bold, design: .monospaced)
                    .foregroundStyle(MorpheTheme.accentText)

                if !moment.detailLine.isEmpty {
                    Text(moment.detailLine.uppercased())
                        .scaledFont(size: 12, weight: .semibold, design: .monospaced)
                        .tracking(1.6)
                        .foregroundStyle(MorpheTheme.textPrimary.opacity(0.55))
                        .padding(.top, 10)
                }

                Rectangle()
                    .fill(MorpheTheme.stroke)
                    .frame(width: 180, height: 1)
                    .padding(.vertical, 24)

                VStack(spacing: 10) {
                    if let card = moment.prCard {
                        Button("Share Card") {
                            Task {
                                sharePayload = ShareCardPayload(
                                    image: await ShareCardRenderer.imageAsync(for: card),
                                    caption: caption
                                )
                            }
                        }
                        .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                        .frame(width: 220)
                    }
                    Button("Done", action: onDismiss)
                        .buttonStyle(SecondaryCTAButtonStyle())
                        .frame(width: 220)
                }
            }
            .padding(36)

            HUDCornerTicks(arm: 22, color: MorpheTheme.textPrimary.opacity(0.35))
                .padding(24)
        }
        .onAppear {
            // The PR signature pair fires for RECORDS only (audit 11,
            // P2-10) — the program-complete stamp keeps the completion cue,
            // or "one signal, one meaning" would already be broken.
            if moment.prCard != nil {
                Haptics.personalRecord()
                SoundEffects.play(.pr)
            } else {
                Haptics.success()
                SoundEffects.play(.star)
            }
        }
        .sheet(item: $sharePayload) { payload in
            ImageShareSheet(image: payload.image, caption: payload.caption) { completed in
                if completed { onShareCompleted() }
                sharePayload = nil
            }
            .presentationDetents([.medium, .large])
        }
        .accessibilityAddTraits(.isModal)
    }
}

struct MorpheAvatarView: View {
    let avatar: AvatarProfile
    let size: CGFloat
    /// The user's real photo — when present it IS the avatar. The audit
    /// found the uploaded photo displayed on exactly one screen; passing it
    /// here puts the face where the identity tile already lives.
    var photoData: Data? = nil

    init(avatar: AvatarProfile, size: CGFloat = 64, photoData: Data? = nil) {
        self.avatar = avatar
        self.size = size
        self.photoData = photoData
    }

    var body: some View {
        // HUD identity tile: flat square, hairline, yellow glyph — the old
        // gold-coin gradient was the last piece of glass in the header.
        ZStack {
            RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                .fill(MorpheTheme.panelStrong)
                .overlay(
                    RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                        .stroke(MorpheTheme.stroke, lineWidth: 1)
                )

            if let photoData, let photo = UIImage(data: photoData) {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous))
            } else {
                Image(systemName: avatar.style.systemImage)
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundStyle(MorpheTheme.accentText)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var shortTitle: String {
        switch avatar.style {
        case .cleanStarter:
            return "Clean"
        case .fightReady:
            return "Fight"
        case .matchFit:
            return "Match"
        case .jumpDay:
            return "Jump"
        case .roadRunner:
            return "Run"
        case .strengthBuilder:
            return "Strength"
        }
    }

}

struct ProfileBannerView: View {
    let banner: BannerProfile
    let theme: ThemePreset

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                .fill(MorpheTheme.panelStrong)
                .overlay(
                    RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                        .stroke(MorpheTheme.strokeStrong.opacity(0.28), lineWidth: 1)
                )
                .overlay(alignment: .topTrailing) {
                    Image(systemName: bannerSymbol(for: banner.preset))
                        .font(.system(.largeTitle).weight(.semibold))
                        .foregroundStyle(MorpheTheme.textPrimary.opacity(0.12))
                        .padding(18)
                }
                .overlay(alignment: .topLeading) {
                    VStack(spacing: 7) {
                        ForEach(0..<8, id: \.self) { _ in
                            Capsule(style: .continuous)
                                .fill(MorpheTheme.panelStrong)
                                .frame(width: 58, height: 1)
                        }
                    }
                    .padding(18)
                }


            VStack(alignment: .leading, spacing: 10) {
                Text(eyebrowText(for: banner.preset))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(MorpheTheme.textPrimary.opacity(0.82))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: MorpheTheme.chipRadius, style: .continuous)
                            .stroke(MorpheTheme.strokeStrong, lineWidth: 1)
                    )

                Text(banner.title)
                    .font(.title.weight(.bold))
                    .foregroundStyle(MorpheTheme.textPrimary)

                Text(banner.subtitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MorpheTheme.textPrimary.opacity(0.84))
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity, minHeight: 148)
    }

    private func eyebrowText(for preset: BannerPreset) -> String {
        switch preset {
        case .boxing: return "MORPHE BOXING"
        case .soccer: return "MATCH READY"
        case .basketball: return "COURT FOCUS"
        case .running: return "ENDURANCE BUILD"
        case .strength: return "STRENGTH TRACK"
        case .fatLoss: return "MOMENTUM MODE"
        case .transformation: return "TRANSFORMATION"
        case .recovery: return "RECOVERY BLOCK"
        case .team: return "TEAM MODE"
        case .minimalPremium: return "MORPHE"
        }
    }

    private func bannerSymbol(for preset: BannerPreset) -> String {
        switch preset {
        case .boxing: return "figure.boxing"
        case .soccer: return "soccerball"
        case .basketball: return "basketball.fill"
        case .running: return "figure.run"
        case .strength: return "dumbbell.fill"
        case .fatLoss: return "flame.fill"
        case .transformation: return "sparkles"
        case .recovery: return "heart.text.square.fill"
        case .team: return "person.3.sequence.fill"
        // A moon reads "sleep tracker"; the reticle is the HUD-native mark.
        case .minimalPremium: return "viewfinder"
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let detail: String?

    init(title: String, value: String, detail: String? = nil) {
        self.title = title
        self.value = value
        self.detail = detail
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(MorpheTheme.textSecondary)
                Text(value)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(MorpheTheme.textPrimary)

                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textMuted)
                }
            }
        }
    }
}

struct NotificationCard: View {
    let item: SmartNotificationItem
    let onAction: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(item.title)
                        .font(.headline)
                        .foregroundStyle(MorpheTheme.textPrimary)
                    Spacer()
                    StatusBadge(text: item.priority.rawValue, color: item.priority == .high ? MorpheTheme.warning : MorpheTheme.accentAlt)
                }

                Text(item.message)
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)

                Button(item.action, action: onAction)
                    .buttonStyle(SecondaryCTAButtonStyle())
            }
        }
    }
}

// (EmptyStateCard used to live here — defined in the design system, used by
// nobody, while every real empty state was hand-rolled inline. An unused
// component is drift bait, so it's gone; the inline states already follow
// the house rule of naming their unlock condition.)

struct ScoreRing: View {
    let score: Int
    let color: Color

    var body: some View {
        // Thin instrument ring: flat color, square cap, mono numerals.
        ZStack {
            Circle()
                .stroke(MorpheTheme.panelStrong, lineWidth: 4)

            Circle()
                .trim(from: 0, to: Double(score) / 100.0)
                .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .butt))
                .rotationEffect(.degrees(-90))
                // The ring sweeps to the new score instead of jump-cutting
                // (feedback pass 2026-09).
                .animation(.easeOut(duration: 0.6), value: score)

            VStack(spacing: 2) {
                Text("\(score)")
                    .font(.system(.title2, design: .monospaced).weight(.bold))
                    .foregroundStyle(MorpheTheme.textPrimary)
                    .contentTransition(.numericText())
                Text("SCORE")
                    .font(MorpheTheme.microLabel(9))
                    .tracking(1.4)
                    .foregroundStyle(MorpheTheme.textMuted)
            }
        }
        .frame(width: 88, height: 88)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Morphe Score"))
        .accessibilityValue(Text("\(score) out of 100"))
    }
}

struct HealthScoreCard: View {
    let health: HealthScoreSummary

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Health Score")
                            .font(.headline)
                            .foregroundStyle(MorpheTheme.textPrimary)
                        Text(health.headline)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(MorpheTheme.textPrimary)
                        Text(health.tier.rawValue)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MorpheTheme.color(for: health.tier))
                    }

                    Spacer()

                    ScoreRing(score: health.score, color: MorpheTheme.color(for: health.tier))
                }

                Text(health.detail)
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)
            }
        }
    }
}

struct AIInsightCard: View {
    let insight: AIInsight

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(insight.title)
                        .font(.headline)
                        .foregroundStyle(MorpheTheme.textPrimary)

                    Spacer()

                    StatusBadge(text: insight.risk.rawValue, color: MorpheTheme.color(for: insight.risk))
                }

                Text(insight.summary)
                    .foregroundStyle(MorpheTheme.textPrimary)

                Text(insight.recommendation)
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)

                Text(insight.suggestedAction)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MorpheTheme.accentText)
            }
        }
    }
}

struct RecoveryScoreCard: View {
    let recovery: RecoverySnapshot

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Recovery Score")
                            .font(.headline)
                            .foregroundStyle(MorpheTheme.textPrimary)
                        Text(recovery.status.rawValue)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(MorpheTheme.textPrimary)
                        Text(recovery.reason)
                            .font(.subheadline)
                            .foregroundStyle(MorpheTheme.textSecondary)
                    }

                    Spacer()

                    ScoreRing(score: recovery.score, color: MorpheTheme.color(for: recovery.status))
                }

                HStack(spacing: 8) {
                    MetricPill(label: "Sleep", value: String(format: "%.1f hr", recovery.sleepHours))
                    MetricPill(label: "Energy", value: "\(recovery.energy)/10")
                    MetricPill(label: "Soreness", value: "\(recovery.soreness)/10")
                }
            }
        }
    }
}

struct SmartPlanAdjustmentCard: View {
    let adjustment: PlanAdjustment

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(adjustment.title)
                    .font(.headline)
                    .foregroundStyle(MorpheTheme.textPrimary)

                Text(adjustment.body)
                    .foregroundStyle(MorpheTheme.textPrimary)

                WrapStack(spacing: 8) {
                    ForEach(adjustment.reasons) { reason in
                        Text(reason.rawValue)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MorpheTheme.textPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                                    .fill(MorpheTheme.panelStrong)
                            )
                    }
                }

                Text(adjustment.recommendation)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MorpheTheme.accentAlt)
            }
        }
    }
}

struct GoalTranslationCard: View {
    let translation: GoalTranslation

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Goal Translation")
                    .font(.headline)
                    .foregroundStyle(MorpheTheme.textPrimary)
                Text(translation.goal)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(MorpheTheme.textPrimary)

                ForEach(translation.weeklyActions, id: \.self) { action in
                    Text("- \(action)")
                        .foregroundStyle(MorpheTheme.textPrimary)
                }
            }
        }
    }
}

struct PersonalRulesCard: View {
    let rules: [PersonalRule]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Personal Rules")
                    .font(.headline)
                    .foregroundStyle(MorpheTheme.textPrimary)
                Text("Morphe uses these rules to adjust your plan.")
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)

                ForEach(rules) { rule in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(rule.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(MorpheTheme.textPrimary)
                        Text(rule.detail)
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textSecondary)
                    }
                }
            }
        }
    }
}

struct WhyThisMattersCard: View {
    let item: WhyThisMatters

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Why this matters")
                    .font(.headline)
                    .foregroundStyle(MorpheTheme.textPrimary)
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MorpheTheme.accentText)
                Text(item.detail)
                    .foregroundStyle(MorpheTheme.textSecondary)
            }
        }
    }
}

struct TaskRow: View {
    let task: TaskItem
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: task.isCompleted ? "checkmark.square.fill" : "square")
                    .foregroundStyle(task.isCompleted ? MorpheTheme.accentText : MorpheTheme.textMuted)
                    .font(.headline)

                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MorpheTheme.textPrimary)
                    Text("\(task.difficulty.rawValue) - \(task.xp) XP")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textSecondary)
                }

                Spacer()
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

struct MinimumWinModeCard: View {
    let message: String
    let tasks: [TaskItem]
    let onToggle: (TaskItem) -> Void
    /// The way back out — activation was a one-way door until midnight,
    /// which read as "my workout is gone" (audit finding).
    var onExit: (() -> Void)? = nil

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Minimum Win Mode")
                        .font(.headline)
                        .foregroundStyle(MorpheTheme.textPrimary)
                    Spacer()
                    if let onExit {
                        Button("Full Plan", action: onExit)
                            .buttonStyle(SecondaryCTAButtonStyle())
                            .frame(width: 96)
                            .accessibilityLabel("Exit Minimum Win mode and restore the full workout")
                    }
                }
                Text(message)
                    .foregroundStyle(MorpheTheme.textSecondary)

                ForEach(tasks) { task in
                    TaskRow(task: task) {
                        onToggle(task)
                    }
                }
            }
        }
    }
}

struct StreakProtectionCard: View {
    let isProtected: Bool
    let options: [String]
    let onSelect: (String) -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Streak Protection")
                    .font(.headline)
                    .foregroundStyle(MorpheTheme.textPrimary)

                if isProtected {
                    Text("Momentum protected.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MorpheTheme.accentText)
                } else {
                    Text("You missed today's workout, but your streak is still saveable.")
                        .foregroundStyle(MorpheTheme.textSecondary)
                    Text("Pick any option below and finish it today — it counts as showing up, and your streak stays alive. Nothing is spent or lost.")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textMuted)

                    WrapStack(spacing: 8) {
                        ForEach(options, id: \.self) { option in
                            Button(option) {
                                onSelect(option)
                            }
                            .buttonStyle(FilterChipStyle(isSelected: false, selectedColor: MorpheTheme.accentAlt))
                        }
                    }
                }
            }
        }
    }
}

struct WorkoutHeroCard: View {
    let workout: WorkoutTemplate
    let onStart: () -> Void
    let onSwitch: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Today's Workout")
                            .font(.headline)
                            .foregroundStyle(MorpheTheme.textPrimary)
                        Text(workout.name)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(MorpheTheme.textPrimary)
                        Text(workout.goal)
                            .font(.subheadline)
                            .foregroundStyle(MorpheTheme.textSecondary)
                    }

                    Spacer()

                    MetricPill(label: "Duration", value: "\(workout.durationMinutes) min")
                }

                HStack(spacing: 8) {
                    MetricPill(label: "Difficulty", value: workout.difficulty.rawValue)
                    MetricPill(label: "Equipment", value: workout.equipment)
                }

                HStack(spacing: 10) {
                    Button("Start Workout", action: onStart)
                        .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))

                    Button("Switch Workout", action: onSwitch)
                        .buttonStyle(SecondaryCTAButtonStyle())
                }
            }
        }
    }
}

struct WorkoutDifficultyFeedbackCard: View {
    let name: String
    let selected: WorkoutFeedbackOption?
    let response: String
    let onSelect: (WorkoutFeedbackOption) -> Void

    var body: some View {
        GlassCard {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkle")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(MorpheTheme.accentText)
                    MorpheWordmark(height: 9)
                        .foregroundStyle(MorpheTheme.textMuted)
                }

                Text(name.isEmpty ? "How did that feel?" : "How did that feel, \(name)?")
                    .font(.headline)
                    .foregroundStyle(MorpheTheme.textPrimary)
                    .multilineTextAlignment(.center)

                // The honest consequence, at the speed it actually moves
                // (audit 10, P2-9): too-easy nudges the NEXT session's
                // suggestion; too-hard shifts the bias over several days.
                Text("Your answers shape the next sessions — too easy nudges the plan up; repeated too-hards ease it off.")
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textMuted)
                    .multilineTextAlignment(.center)

                WrapStack(spacing: 8) {
                    ForEach(WorkoutFeedbackOption.allCases) { option in
                        Button(option.rawValue) {
                            onSelect(option)
                        }
                        .buttonStyle(FilterChipStyle(isSelected: selected == option, selectedColor: MorpheTheme.accentAlt))
                    }
                }

                if !response.isEmpty {
                    Text(response)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MorpheTheme.accentText)
                        .multilineTextAlignment(.center)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct FrictionInsightCard: View {
    let insight: FrictionInsight
    let onNext: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Pattern Insights")
                        .font(.headline)
                        .foregroundStyle(MorpheTheme.textPrimary)
                    Spacer()
                    Button("Next", action: onNext)
                        .buttonStyle(SecondaryCTAButtonStyle())
                        .frame(width: 88)
                }

                Text(insight.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MorpheTheme.accentText)

                Text(insight.summary)
                    .foregroundStyle(MorpheTheme.textPrimary)

                Text(insight.recommendation)
                    .foregroundStyle(MorpheTheme.textSecondary)
            }
        }
    }
}

struct TransformationRoadmapCard: View {
    let phases: [RoadmapPhase]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Transformation Roadmap")
                    .font(.headline)
                    .foregroundStyle(MorpheTheme.textPrimary)

                ForEach(phases) { phase in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            HStack(spacing: 8) {
                                Image(systemName: iconName(for: phase.status))
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(color(for: phase.status))
                                Text(phase.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(MorpheTheme.textPrimary)
                            }
                            Spacer()
                            Text(phase.status)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(color(for: phase.status))
                        }

                        Text(phase.focus)
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textSecondary)

                        Text("Milestone: \(phase.milestone)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MorpheTheme.accentAlt)
                    }
                }
            }
        }
    }

    private func color(for status: String) -> Color {
        switch status {
        case "Done":
            return Color(red: 0.40, green: 0.86, blue: 0.54)
        case "Current":
            return MorpheTheme.accent
        case "Up Next":
            return MorpheTheme.textMuted
        case "Locked":
            return MorpheTheme.danger
        default:
            return MorpheTheme.textSecondary
        }
    }

    private func iconName(for status: String) -> String {
        switch status {
        case "Done":
            return "checkmark.circle.fill"
        case "Current":
            return "largecircle.fill.circle"
        case "Up Next":
            return "circle.dashed"
        case "Locked":
            return "lock.circle.fill"
        default:
            return "circle"
        }
    }
}

struct PhotoProgressAIScanCard: View {
    let snapshot: PhotoProgressSnapshot

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Photo Progress + AI Scan")
                    .font(.headline)
                    .foregroundStyle(MorpheTheme.textPrimary)

                HStack(spacing: 8) {
                    PhotoSlotView(label: snapshot.frontLabel)
                    PhotoSlotView(label: snapshot.sideLabel)
                    PhotoSlotView(label: snapshot.backLabel)
                }

                Text(snapshot.reminder)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MorpheTheme.accentText)
                Text(snapshot.aiPreview)
                    .foregroundStyle(MorpheTheme.textPrimary)
                Text(snapshot.postureNote)
                    .foregroundStyle(MorpheTheme.textSecondary)
                Text(snapshot.compositionTrend)
                    .foregroundStyle(MorpheTheme.textSecondary)
                Text(snapshot.privacyNote)
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textMuted)
            }
        }
    }
}

struct SportModeSelector: View {
    let selected: SportFocus
    let onSelect: (SportFocus) -> Void

    private let featuredSports: [SportFocus] = [
        .generalFitness,
        .boxing,
        .soccer,
        .basketball,
        .running,
        .hybridAthlete
    ]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Sport-Specific Mode")
                    .font(.headline)
                    .foregroundStyle(MorpheTheme.textPrimary)
                Text("Training type changes the goals, drills, and metrics Morphe highlights.")
                    .foregroundStyle(MorpheTheme.textSecondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(featuredSports) { sport in
                            Button(sport.shortTitle) {
                                onSelect(sport)
                            }
                            .buttonStyle(FilterChipStyle(isSelected: selected == sport, selectedColor: MorpheTheme.color(for: sport)))
                        }
                    }
                }
                .pageSwipeExempt()
            }
        }
    }
}

struct SportMetricsCard: View {
    let sport: SportFocus
    let metrics: [SportMetric]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("\(sport.rawValue) Focus")
                        .font(.headline)
                        .foregroundStyle(MorpheTheme.textPrimary)
                    Spacer()
                    StatusBadge(text: sport.shortTitle, color: MorpheTheme.color(for: sport))
                }

                ForEach(metrics) { metric in
                    HStack {
                        Text(metric.label)
                            .foregroundStyle(MorpheTheme.textSecondary)
                        Spacer()
                        Text(metric.value)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(MorpheTheme.textPrimary)
                    }
                }
            }
        }
    }
}

struct SmartNotificationPreviewCard: View {
    let notifications: [SmartNotificationItem]
    let onAction: (SmartNotificationItem) -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Smart Notifications")
                    .font(.headline)
                    .foregroundStyle(MorpheTheme.textPrimary)

                ForEach(Array(notifications.prefix(3))) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(item.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(MorpheTheme.textPrimary)
                            Spacer()
                            StatusBadge(text: item.priority.rawValue, color: item.priority == .high ? MorpheTheme.warning : MorpheTheme.accentAlt)
                        }
                        Text(item.message)
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textSecondary)
                        Button(item.action) {
                            onAction(item)
                        }
                        .buttonStyle(SecondaryCTAButtonStyle())
                    }
                }
            }
        }
    }
}

struct LevelProgressCard: View {
    let progress: LevelProgress

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Level")
                    .font(.headline)
                    .foregroundStyle(MorpheTheme.textPrimary)

                Text(progress.currentTitle)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(MorpheTheme.textPrimary)

                ProgressBarView(progress: progress.progress, color: MorpheTheme.accent)

                HStack {
                    Text("XP \(progress.currentXP) / \(progress.targetXP)")
                        .foregroundStyle(MorpheTheme.textSecondary)
                    Spacer()
                    Text(progress.streak == 1 ? "Streak 1 day" : "Streak \(progress.streak) days")
                        .foregroundStyle(MorpheTheme.textSecondary)
                }
                .font(.subheadline)

                Text("Next Level: \(progress.nextTitle)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MorpheTheme.textPrimary)
            }
        }
    }
}

struct QuickActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: systemImage)
                    .font(.headline)
                    .foregroundStyle(MorpheTheme.textPrimary)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MorpheTheme.textPrimary)
                    .multilineTextAlignment(.leading)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                    .fill(MorpheTheme.panelStrong)
            )
            .overlay(
                RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                    .stroke(MorpheTheme.stroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
    }
}


struct BottomTabNavigation<Item: MorpheTabItem & CaseIterable>: View where Item.AllCases == [Item] {
    let items: [Item]
    let selected: Item
    /// Count badges per tab (0 = none).
    var badges: [Item: Int] = [:]
    let onSelect: (Item) -> Void

    var body: some View {
        MorpheTabBar(items: items, selected: selected, badges: badges, onSelect: onSelect)
    }
}

/// The red count pill every messaging app wears top-right of an icon.
struct CountBadge: View {
    let count: Int
    var body: some View {
        Text(count > 99 ? "99+" : "\(count)")
            .font(.system(size: 10, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .frame(minWidth: 17, minHeight: 17)
            .background(Capsule().fill(MorpheTheme.danger))
            .overlay(Capsule().stroke(Color.black.opacity(0.25), lineWidth: 0.5))
            .accessibilityLabel("\(count) new")
    }
}

struct MorpheTabBar<Item: MorpheTabItem & CaseIterable>: View where Item.AllCases == [Item] {
    let items: [Item]
    let selected: Item
    var badges: [Item: Int] = [:]
    let onSelect: (Item) -> Void

    var body: some View {
        // HUD dock, icons only: a slim ink strip under a single top hairline.
        // The active tab is yellow with a 4pt dot beneath it, so state
        // survives without words; VoiceOver still speaks each tab's title.
        HStack(spacing: 4) {
            ForEach(items, id: \.self) { item in
                Button {
                    // The most-pressed control in the app gets the same
                    // selection tick as every chip.
                    Haptics.selection()
                    onSelect(item)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.systemImage)
                            .font(.system(size: 21, weight: .semibold))
                            .overlay(alignment: .topTrailing) {
                                if let count = badges[item], count > 0 {
                                    CountBadge(count: count)
                                        .offset(x: 10, y: -8)
                                }
                            }
                        // Named, not icons-only: six abstract glyphs made
                        // new users guess what Discover/Network/Learn were
                        // (audit BLOCKER). Mono micro-labels keep the HUD.
                        Text(item.title.uppercased())
                            .font(MorpheTheme.microLabel(10))
                            .tracking(0.8)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Circle()
                            .fill(selected == item ? MorpheTheme.accentText : .clear)
                            .frame(width: 4, height: 4)
                    }
                    // accentText, not raw accent (audit 12, P1-5): the
                    // capsule material resolves near-white in light mode.
                    .foregroundStyle(selected == item ? MorpheTheme.accentText : MorpheTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text((badges[item] ?? 0) > 0 ? "\(item.title), \(badges[item]!) new" : item.title))
                .accessibilityAddTraits(selected == item ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
        // Floating glass bubble (Lucas 2026-08-19): the dock lifts off the
        // bottom and sides in a material capsule — the Liquid Glass
        // floating-capsule pattern from docs/archive/UI-AUDIT-APPLE.md, scoped to
        // chrome exactly as the benchmark prescribes. Same height as the
        // full-width strip it replaces.
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(MorpheTheme.stroke, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.11), radius: 3, y: 2)
                .shadow(color: .black.opacity(0.11), radius: 20, y: 11)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }
}

struct ClientSnapshotCard: View {
    let client: CoachClient
    let onMessage: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(client.name)
                            .font(.headline)
                            .foregroundStyle(MorpheTheme.textPrimary)
                        Text(client.goal)
                            .font(.subheadline)
                            .foregroundStyle(MorpheTheme.textSecondary)
                    }

                    Spacer()

                    StatusBadge(text: client.statusText, color: MorpheTheme.color(for: client.risk))
                }

                HStack(spacing: 8) {
                    MetricPill(label: "Sport", value: client.sport.shortTitle)
                    MetricPill(label: "Recovery", value: "\(client.recoveryScore.score)")
                    MetricPill(label: "Compliance", value: "\(client.complianceScore)%")
                }

                Button("Quick Message", action: onMessage)
                    .buttonStyle(SecondaryCTAButtonStyle())
            }
        }
    }
}

struct BadgeGridCard: View {
    let badges: [ProfileBadge]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Badges")
                    .font(.headline)
                    .foregroundStyle(MorpheTheme.textPrimary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(badges) { badge in
                        VStack(alignment: .leading, spacing: 8) {
                            Image(systemName: badge.icon)
                                .foregroundStyle(badge.earned ? MorpheTheme.accentText : MorpheTheme.textMuted)
                            Text(badge.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(badge.earned ? MorpheTheme.textPrimary : MorpheTheme.textMuted)
                            Text(badge.detail)
                                .font(.caption)
                                .foregroundStyle(badge.earned ? MorpheTheme.textSecondary : MorpheTheme.textMuted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(
                            // Unearned = the outline goal (Apple A3): the
                            // badge is visible, its unlock condition named,
                            // nothing pretends to be won.
                            RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                                .fill(badge.earned ? MorpheTheme.panelStrong : Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                                        .stroke(badge.earned ? Color.clear : MorpheTheme.stroke,
                                                style: StrokeStyle(lineWidth: 1, dash: badge.earned ? [] : [5, 4]))
                                )
                        )
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(badge.earned
                            ? "\(badge.title), earned. \(badge.detail)"
                            : "\(badge.title), not earned yet. \(badge.detail)")
                    }
                }
            }
        }
    }
}

struct CalendarEventCard: View {
    let event: CalendarEvent
    let onReschedule: () -> Void
    let onComplete: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.title)
                            .font(.headline)
                            .foregroundStyle(MorpheTheme.textPrimary)
                        Text("\(event.day) - \(event.time)")
                            .font(.subheadline)
                            .foregroundStyle(MorpheTheme.textSecondary)
                    }

                    Spacer()

                    StatusBadge(text: event.type.rawValue, color: MorpheTheme.accentAlt)
                }

                Text(event.detail)
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textPrimary)

                HStack(spacing: 10) {
                    Button("Reschedule", action: onReschedule)
                        .buttonStyle(SecondaryCTAButtonStyle())

                    Button(event.isComplete ? "Completed" : "Mark Complete", action: onComplete)
                        .buttonStyle(PrimaryCTAButtonStyle(accent: event.isComplete ? MorpheTheme.accentAlt : MorpheTheme.accent))
                }
            }
        }
    }
}

struct FilterChipStyle: ButtonStyle {
    let isSelected: Bool
    var selectedColor: Color = MorpheTheme.accent

    private var selectedForeground: Color {
        // Hardcoded black text went black-on-black for the dark sport
        // colors in light mode (UX test 2026-09-30) — the ink follows
        // the fill, at the WCAG crossover.
        MorpheTheme.onFill(selectedColor)
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isSelected ? selectedForeground : MorpheTheme.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            // Glass chip, tinted when selected (Lucas 2026-10-17).
            .morpheGlass(RoundedRectangle(cornerRadius: MorpheTheme.chipRadius, style: .continuous),
                         tint: isSelected ? selectedColor.opacity(0.92) : nil)
            // Selection was color-only — invisible to VoiceOver and weak for
            // color-blind users. Every chip in the app gets the trait from here.
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            // No press-down tick here (feedback audit 2026-10-16, F3): it
            // fired on every chip, list filters included, and doubled the
            // tick on chips whose action already reported a value change.
            // The tick belongs to the value change — `sensoryFeedback` at
            // the owner, or the action's own Haptics.selection().
    }
}

struct MorpheFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<_Label>) -> some View {
        configuration
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                    .fill(MorpheTheme.panel)
                    .overlay(
                        RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                            .stroke(MorpheTheme.stroke, lineWidth: 1)
                    )
            )
            .foregroundStyle(MorpheTheme.textPrimary)
    }
}

private struct PhotoSlotView: View {
    let label: String

    var body: some View {
        RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
            .fill(MorpheTheme.panelStrong)
            .overlay(
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .foregroundStyle(MorpheTheme.textPrimary)
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(8)
            )
            .frame(maxWidth: .infinity, minHeight: 100)
    }
}

/// Flat HUD accordion for system DisclosureGroups: label, hairline rule,
/// yellow +/- state — matches the Home/Train section disclosures.
struct HUDDisclosureStyle: DisclosureGroupStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    configuration.isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    configuration.label

                    Rectangle()
                        .fill(MorpheTheme.stroke)
                        .frame(height: 1)
                        .frame(maxWidth: .infinity)

                    Image(systemName: configuration.isExpanded ? "minus" : "plus")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(MorpheTheme.accentText)
                        .accessibilityHidden(true)
                }
                // A full 44pt row (audit 29: one text line was a 20pt
                // target), and VoiceOver hears the state, not "Add".
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(configuration.isExpanded ? "Expanded" : "Collapsed")

            if configuration.isExpanded {
                configuration.content
            }
        }
    }
}

struct WrapStack<Content: View>: View {
    let spacing: CGFloat
    let content: Content

    init(spacing: CGFloat = 8, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 130), spacing: spacing, alignment: .leading)],
            alignment: .leading,
            spacing: spacing
        ) {
            content
        }
    }
}

// MARK: - Fetch states (shared by every fetched surface)

/// Placeholder while a FIRST fetch answers — empty copy before the
/// network has spoken is a lie.
struct FetchPlaceholderCard: View {
    let line: String

    var body: some View {
        GlassCard(.quiet) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(0..<2, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: MorpheTheme.chipRadius, style: .continuous)
                        .fill(MorpheTheme.panelStrong)
                        .frame(height: 14)
                }
                Text(line.uppercased())
                    .font(MorpheTheme.microLabel())
                    .tracking(1.2)
                    .foregroundStyle(MorpheTheme.textMuted)
            }
        }
        .accessibilityLabel(line)
    }
}

/// A failure the user can see and act on — never a silent empty screen.
struct FetchRetryCard: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        GlassCard(.quiet) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MorpheTheme.warning)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(MorpheTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button("Retry", action: onRetry)
                    .buttonStyle(SecondaryCTAButtonStyle())
                    .frame(width: 118)
            }
        }
        .onAppear { Haptics.error() }
    }
}

// MARK: - Manifesto (the house rules, said out loud)
//
// The brand promise as a user-facing card. Every line is enforced in code —
// if a line stops being true, the fix is the product, not this copy.

struct ManifestoCard: View {
    var body: some View {
        GlassCard(.quiet) {
            VStack(alignment: .leading, spacing: 14) {
                Text("WHY MORPHE")
                    .font(MorpheTheme.microLabel())
                    .tracking(1.4)
                    .foregroundStyle(MorpheTheme.accentText)

                VStack(alignment: .leading, spacing: 12) {
                    ManifestoLine(index: 1, title: "Real scores only",
                                  detail: "Every stat is computed from sets you actually logged.")
                    ManifestoLine(index: 2, title: "No ads. No trackers.",
                                  detail: "Your numbers are yours — never sold, never used to target you.")
                    ManifestoLine(index: 3, title: "Safety stays free",
                                  detail: "Your data, your export, and every safety feature — free, always.")
                    ManifestoLine(index: 4, title: "Nothing fake",
                                  detail: "No invented streaks, no padded progress. If Morphe shows it, you did it.")
                }

                Rectangle()
                    .fill(MorpheTheme.stroke)
                    .frame(height: 1)

                // Brand yellow on purpose — the motto doesn't follow the
                // user's accent palette, same as the share card footer.
                Text(MorpheTheme.tagline)
                    .scaledFont(size: 13, weight: .bold, design: .monospaced)
                    .tracking(2.4)
                    .foregroundStyle(MorpheTheme.accentText)
            }
        }
    }
}

private struct ManifestoLine: View {
    let index: Int
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(String(format: "%02d", index))
                .font(MorpheTheme.microLabel(11))
                .tracking(1.2)
                .foregroundStyle(MorpheTheme.accentText)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MorpheTheme.textPrimary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Share card (the outward face of a session)
//
// A branded 9:16 story image rendered on demand with ImageRenderer — the
// telemetry HUD look, sized for IG/Snap stories. Every number on it is a
// logged fact from ShareCardData; there is nothing to embellish.

/// Shared 9:16 poster chrome: ink canvas, wordmark + date header, hairline
/// footer with handle + motto, corner ticks. Each card variant supplies
/// only its middle block.
private struct ShareCardFrame<Content: View>: View {
    let dateLabel: String
    let username: String
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            Color.black

            VStack(alignment: .leading, spacing: 0) {
                // Header: wordmark + date.
                HStack {
                    MorpheWordmark(height: 22)
                        .foregroundStyle(MorpheTheme.accentOnInk)
                    Spacer()
                    Text(dateLabel.uppercased())
                        .font(.system(size: 11, design: .monospaced).weight(.semibold))
                        .tracking(1.6)
                        .foregroundStyle(Color.white.opacity(0.55))
                }

                Spacer()

                content

                Spacer()

                // Footer: hairline + handle + motto.
                Rectangle()
                    .fill(Color.white.opacity(0.18))
                    .frame(height: 1)
                    .padding(.bottom, 12)
                HStack {
                    if !username.isEmpty {
                        Text(username.uppercased())
                            .font(.system(size: 12, design: .monospaced).weight(.semibold))
                            .tracking(1.6)
                            .foregroundStyle(Color.white.opacity(0.7))
                    }
                    Spacer()
                    // The motto rides every card — the brand line travels
                    // with the stats, not instead of them.
                    Text(MorpheTheme.tagline)
                        .font(.system(size: 12, design: .monospaced).weight(.bold))
                        .tracking(1.6)
                        // Lit blue: the card is always dark and #2957D9
                        // reads 3.5:1 on it (audit 28, P1).
                        .foregroundStyle(Color(red: 0.478, green: 0.635, blue: 1.0))
                }
            }
            .padding(36)

            // The HUD corner ticks, scaled up for the poster format.
            HUDCornerTicks(arm: 16, color: Color.white.opacity(0.35))
                .padding(18)
        }
        .frame(width: 360, height: 640)
    }
}

/// The mono tracked section label every card opens with.
private struct ShareCardKicker: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, design: .monospaced).weight(.semibold))
            .tracking(2.4)
            .foregroundStyle(Color.white.opacity(0.55))
    }
}

struct ShareCardView: View {
    let data: ShareCardData

    private var factLine: String {
        var facts: [String] = []
        if data.setCount > 0 { facts.append("\(data.setCount) \(data.unitLabel)") }
        if data.exerciseCount > 0 { facts.append("\(data.exerciseCount) MOVES") }
        if data.minutes > 0 { facts.append("\(data.minutes) MIN") }
        return facts.joined(separator: "   ·   ")
    }

    var body: some View {
        ShareCardFrame(dateLabel: data.dateLabel, username: data.username) {
            VStack(alignment: .leading, spacing: 0) {
                ShareCardKicker(text: "SESSION LOGGED")
                    .padding(.bottom, 10)

                Text(data.workoutName)
                    .font(.system(size: 40, weight: .black))
                    .foregroundStyle(Color.white)
                    .lineLimit(3)
                    .minimumScaleFactor(0.6)
                    .padding(.bottom, 18)

                if !factLine.isEmpty {
                    Text(factLine)
                        .font(.system(size: 15, design: .monospaced).weight(.bold))
                        .tracking(1.2)
                        .foregroundStyle(Color(red: 0.478, green: 0.635, blue: 1.0))
                        .padding(.bottom, 18)
                }

                ForEach(data.prNames, id: \.self) { name in
                    HStack(spacing: 8) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(MorpheTheme.accentOnInk)
                        Text("NEW PR · \(name.uppercased())")
                            .font(.system(size: 13, design: .monospaced).weight(.bold))
                            .tracking(1.2)
                            .foregroundStyle(Color.white)
                            .lineLimit(1)
                    }
                    .padding(.bottom, 8)
                }

                if data.streak >= 2 {
                    HStack(spacing: 8) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(MorpheTheme.accentOnInk)
                        Text("\(data.streak)-DAY STREAK")
                            .font(.system(size: 13, design: .monospaced).weight(.bold))
                            .tracking(1.2)
                            .foregroundStyle(Color.white)
                    }
                    .padding(.top, 4)
                }
            }
        }
    }
}

/// One PR, one poster. The weight is the hero; the "up from" row only
/// renders when the beaten record is actually known.
struct PRShareCardView: View {
    let data: PRShareCardData

    var body: some View {
        ShareCardFrame(dateLabel: data.dateLabel, username: data.username) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(MorpheTheme.accentOnInk)
                    ShareCardKicker(text: "NEW RECORD")
                }
                .padding(.bottom, 10)

                Text(data.exerciseName)
                    .font(.system(size: 40, weight: .black))
                    .foregroundStyle(Color.white)
                    .lineLimit(3)
                    .minimumScaleFactor(0.6)
                    .padding(.bottom, 18)

                Text(data.weightLabel.uppercased())
                    .font(.system(size: 34, design: .monospaced).weight(.bold))
                    .foregroundStyle(MorpheTheme.accentOnInk)

                if !data.previousLabel.isEmpty {
                    Text("UP FROM \(data.previousLabel.uppercased())")
                        .font(.system(size: 13, design: .monospaced).weight(.semibold))
                        .tracking(1.2)
                        .foregroundStyle(Color.white.opacity(0.55))
                        .padding(.top, 10)
                }
            }
        }
    }
}

/// The schedule-aware streak as a poster — the number is the whole story.
struct StreakShareCardView: View {
    let data: StreakShareCardData

    var body: some View {
        ShareCardFrame(dateLabel: data.dateLabel, username: data.username) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(MorpheTheme.accentOnInk)
                    ShareCardKicker(text: "CONSISTENCY")
                }
                .padding(.bottom, 14)

                Text("\(data.streak)")
                    .font(.system(size: 96, design: .monospaced).weight(.bold))
                    .foregroundStyle(MorpheTheme.accentOnInk)

                Text("DAY STREAK")
                    .font(.system(size: 18, design: .monospaced).weight(.bold))
                    .tracking(3)
                    .foregroundStyle(Color.white)
                    .padding(.bottom, 14)

                Text("EVERY DAY EARNED")
                    .font(.system(size: 12, design: .monospaced).weight(.semibold))
                    .tracking(1.6)
                    .foregroundStyle(Color.white.opacity(0.55))
            }
        }
    }
}

/// One completed week as a poster — sessions lead, the facts ride below.
struct RecapShareCardView: View {
    let data: WeeklyRecapData

    var body: some View {
        ShareCardFrame(dateLabel: data.rangeLabel, username: data.username) {
            VStack(alignment: .leading, spacing: 0) {
                ShareCardKicker(text: "WEEK IN REVIEW")
                    .padding(.bottom, 14)

                Text("\(data.sessions)")
                    .font(.system(size: 96, design: .monospaced).weight(.bold))
                    .foregroundStyle(MorpheTheme.accentOnInk)

                Text(data.sessions == 1 ? "SESSION" : "SESSIONS")
                    .font(.system(size: 18, design: .monospaced).weight(.bold))
                    .tracking(3)
                    .foregroundStyle(Color.white)
                    .padding(.bottom, 16)

                Text("\(data.sets) SETS   ·   \(data.minutes) MIN")
                    .font(.system(size: 15, design: .monospaced).weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(Color.white)

                if data.prCount > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(MorpheTheme.accentOnInk)
                        Text("\(data.prCount) NEW PR\(data.prCount == 1 ? "" : "S")")
                            .font(.system(size: 13, design: .monospaced).weight(.bold))
                            .tracking(1.2)
                            .foregroundStyle(Color.white)
                    }
                    .padding(.top, 12)
                }

                if data.streak >= 2 {
                    HStack(spacing: 8) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(MorpheTheme.accentOnInk)
                        Text("\(data.streak)-DAY STREAK")
                            .font(.system(size: 13, design: .monospaced).weight(.bold))
                            .tracking(1.2)
                            .foregroundStyle(Color.white)
                    }
                    .padding(.top, 8)
                }
            }
        }
    }
}

@MainActor
enum ShareCardRenderer {
    /// 360×640 view at 3× = a 1080×1920 story-ready PNG.
    static func image(for data: ShareCardData) -> UIImage? {
        render(ShareCardView(data: data))
    }

    static func image(for data: WeeklyRecapData) -> UIImage? {
        render(RecapShareCardView(data: data))
    }

    static func image(for data: PRShareCardData) -> UIImage? {
        render(PRShareCardView(data: data))
    }

    static func image(for data: StreakShareCardData) -> UIImage? {
        render(StreakShareCardView(data: data))
    }

    private static func render(_ view: some View) -> UIImage? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        return renderer.uiImage
    }
}

// Async rendering: ImageRenderer is MainActor-isolated (the compiler
// enforces it), so the 3x poster raster still runs on main — but these
// wrappers detach it from the share tap's OWN transaction: the button
// feedback and sheet presentation commit first, then the render lands.
// A true off-main render needs a CoreGraphics re-implementation of the
// cards (Tools/make_brand_assets.swift has one) — deferred.
extension ShareCardRenderer {
    static func imageAsync(for data: ShareCardData) async -> UIImage? {
        await Task.yield()
        return image(for: data)
    }

    static func imageAsync(for data: PRShareCardData) async -> UIImage? {
        await Task.yield()
        return image(for: data)
    }

    static func imageAsync(for data: StreakShareCardData) async -> UIImage? {
        await Task.yield()
        return image(for: data)
    }

    static func imageAsync(for data: WeeklyRecapData) async -> UIImage? {
        await Task.yield()
        return image(for: data)
    }
}

/// A rendered card + caption, alive while a share sheet is up — the shared
/// Identifiable payload for every card-share entry point.
struct ShareCardPayload: Identifiable {
    let id = UUID()
    /// Nil = render failed; the sheet shares the caption text alone.
    let image: UIImage?
    let caption: String
}

/// System share sheet for a rendered card image (+ caption text). Same
/// completion-dismiss contract as the data-export sheet: finishing or
/// cancelling the share closes the hosting SwiftUI sheet too.
struct ImageShareSheet: UIViewControllerRepresentable {
    /// Nil = share the caption text alone (render-failure fallback).
    let image: UIImage?
    let caption: String
    /// `completed` distinguishes a real share from a cancelled sheet —
    /// the share-loop telemetry only counts the former.
    let onFinish: (_ completed: Bool) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let items: [Any] = image.map { [$0, caption] } ?? [caption]
        let controller = UIActivityViewController(
            activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, _ in
            onFinish(completed)
        }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}


// MARK: - Feature glimmer (Lucas 2026-10-10)

/// A sheen that sweeps across a headline so the core features — Hey
/// Morphe, Form Check, Check a Food, Build Workout — read as the doors
/// they are. One pass shortly after the view appears, then one every
/// seven seconds while it stays on screen; the band is the rank accent
/// lifted toward white, masked to the text itself. Reduce Motion gets
/// the static accent-lit gradient instead of the sweep.
struct FeatureGlimmer: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -0.6
    var period: TimeInterval = 7

    func body(content: Content) -> some View {
        content
            .overlay {
                // Reduce Motion: nothing extra — the headline keeps its own
                // color (audit 2026-10-12: a static gradient recolored the
                // accent-tinted Form button).
                if !reduceMotion {
                    GeometryReader { geo in
                        // accentText only, never white (audit 2026-10-12,
                        // P1): a white peak over near-black light-mode text
                        // erased the headline mid-sweep. Same rule as the
                        // older sheen above (audit 7, P1-2).
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: MorpheTheme.accentText.opacity(0.85), location: 0.5),
                                .init(color: .clear, location: 1)
                            ],
                            startPoint: .leading, endPoint: .trailing
                        )
                        .frame(width: max(geo.size.width * 0.45, 32))
                        .offset(x: phase * geo.size.width)
                        .rotationEffect(.degrees(14))
                    }
                    .mask(content)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
            }
            // Restarts when Reduce Motion flips while the view is on screen.
            .task(id: reduceMotion) {
                guard !reduceMotion else { return }
                try? await Task.sleep(for: .milliseconds(500))
                while !Task.isCancelled {
                    // Reset with no animation, let a frame land, then sweep:
                    // resetting and animating in one tick animated 1.1 → 1.1
                    // after the first pass, so it swept once (audit P1).
                    var reset = Transaction(); reset.disablesAnimations = true
                    withTransaction(reset) { phase = -0.6 }
                    try? await Task.sleep(for: .milliseconds(32))
                    withAnimation(.easeInOut(duration: 1.15)) { phase = 1.1 }
                    try? await Task.sleep(for: .seconds(period))
                }
            }
    }
}

extension View {
    /// Marks a core-feature headline with the sweeping sheen.
    func featureGlimmer(period: TimeInterval = 7) -> some View {
        modifier(FeatureGlimmer(period: period))
    }
}

// MARK: - The Morphe wordmark (final logo, Lucas 2026-10-13)

/// The one Morphe logo. A template image, so it takes the color of its
/// context (white on dark, ink on light, the rank accent where asked);
/// sized by cap height, width follows the mark's ~5.25 : 1 proportion.
/// Anywhere the brand NAME appears as a logo, use this — never typed text.
struct MorpheWordmark: View {
    var height: CGFloat
    /// The blue under-glow; off where the mark sits in a toolbar (the AI
    /// chat header, Lucas 2026-10-15).
    var glows: Bool = true

    var body: some View {
        Image("MorpheWordmark")
            .renderingMode(.template)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(height: height)
            // A slight blue glow underneath (Lucas 2026-10-13): Spartan
            // blue, sitting just below the letters, scaled to the mark.
            .shadow(color: glows ? MorpheTheme.brandBlue.opacity(0.55) : .clear, radius: max(2, height * 0.35), x: 0, y: max(1, height * 0.18))
            .accessibilityLabel("Morphe")
    }
}

// MARK: - Page swipe inside a tab (Lucas 2026-10-13)

/// Left/right swipes move between the pages INSIDE a tab (Discover:
/// Workouts ↔ Feed; Network: Chats ↔ Board ↔ Calendar; Learn: Lessons ↔
/// Nutrition ↔ Library). The main tabs no longer page — the dock switches
/// them. Only a clearly horizontal drag counts, so vertical scrolling and
/// taps are untouched.
struct InTabPageSwipe<Page: Hashable>: ViewModifier {
    let pages: [Page]
    @Binding var selection: Page
    /// Past the last page a swipe comes back around (Discover's two pages:
    /// either direction flips, Lucas 2026-10-17).
    var wraps = false
    /// Areas that scroll sideways on their own (rails, chip rows): a drag
    /// that STARTS in one belongs to it, never to the page (2026-10-15 —
    /// swiping "New this week" flipped Discover to the Feed).
    @State private var exemptFrames: [CGRect] = []

    func body(content: Content) -> some View {
        // The shell owns the swipe now (Lucas 2026-10-17: one sequence
        // through every page, wrapping) — see AppSwipeHost. The exempt
        // frames (rails, chip rows) still post up to it.
        content
    }
}

/// The one horizontal swipe for the whole app: a UIKit pan over the tab
/// shell. Left = next stop, right = previous, wrapping. Drags that start
/// on a sideways-scrolling area (rails, chip rows) are left alone, and the
/// pan never cancels the touch under it, so a swipe can't trigger a button
/// — buttons fire on a clean tap only, scroll views keep their scroll.
struct AppSwipeHost: ViewModifier {
    @Environment(MorpheAppStore.self) private var store
    @State private var exemptFrames: [CGRect] = []

    func body(content: Content) -> some View {
        content
            .coordinateSpace(name: PageSwipeSpace.name)
            .onPreferenceChange(PageSwipeExemptKey.self) { exemptFrames = $0 }
            .overlay(
                PageSwipeRecognizer { start, dx, dy in
                    guard !store.appSwipeBlocked else { return }
                    guard !exemptFrames.contains(where: { $0.contains(start) }) else { return }
                    guard abs(dx) > 70, abs(dx) > abs(dy) * 1.6 else { return }
                    store.moveStop(by: dx < 0 ? 1 : -1)
                }
                .allowsHitTesting(false)
            )
    }
}

extension View {
    func appSwipeHost() -> some View { modifier(AppSwipeHost()) }
}

/// A pan recognizer attached to the page's host view so it sees every
/// touch in the page, scroll views included, without stealing them
/// (`cancelsTouchesInView = false`, simultaneous with everything). Reports
/// the start point (in the page's space) and the translation on release.
struct PageSwipeRecognizer: UIViewRepresentable {
    let onSwipe: (CGPoint, CGFloat, CGFloat) -> Void

    func makeUIView(context: Context) -> HostView {
        let view = HostView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = nil
        view.onSwipe = onSwipe
        return view
    }
    func updateUIView(_ view: HostView, context: Context) { view.onSwipe = onSwipe }
    static func dismantleUIView(_ view: HostView, coordinator: ()) { view.detach() }

    final class HostView: UIView, UIGestureRecognizerDelegate {
        var onSwipe: ((CGPoint, CGFloat, CGFloat) -> Void)?
        private var pan: UIPanGestureRecognizer?
        private weak var host: UIView?
        private var start: CGPoint = .zero
        private var tracking = false

        override func didMoveToWindow() {
            super.didMoveToWindow()
            // The window, not the superview: SwiftUI wraps a representable
            // in a container its own size, so a recognizer there never
            // sees the page's touches. The window sees them all; `began`
            // filters to touches that landed on this page.
            guard let host = window, pan == nil else { return }
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handle(_:)))
            pan.delegate = self
            pan.cancelsTouchesInView = false
            pan.delaysTouchesBegan = false
            host.addGestureRecognizer(pan)
            self.pan = pan
            self.host = host
        }

        func detach() {
            if let pan, let host { host.removeGestureRecognizer(pan) }
            pan = nil
        }

        /// False when any ancestor is hidden or fully transparent.
        private var isShowing: Bool {
            var view: UIView? = self
            while let v = view {
                if v.isHidden || v.alpha < 0.01 { return false }
                view = v.superview
            }
            return true
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }

        @objc private func handle(_ gesture: UIPanGestureRecognizer) {
            switch gesture.state {
            case .began:
                let point = gesture.location(in: self)
                // Only touches that landed on this page while it is showing
                // (the window is shared with every tab and sheet).
                // Never under a sheet or a full-screen cover: they share the
                // window, so a drag inside Quick Add or Search would flip
                // the page beneath (integration audit 2026-10-17).
                let presented = window?.rootViewController?.presentedViewController != nil
                tracking = bounds.contains(point) && isShowing && !presented
                start = point
            case .ended:
                guard tracking else { return }
                tracking = false
                let t = gesture.translation(in: self)
                onSwipe?(start, t.x, t.y)
            case .cancelled, .failed:
                tracking = false
            default:
                break
            }
        }
    }
}

enum PageSwipeSpace {
    static let name = "morphe.inTabPageSwipe"
}

struct PageSwipeExemptKey: PreferenceKey {
    static let defaultValue: [CGRect] = []
    static func reduce(value: inout [CGRect], nextValue: () -> [CGRect]) {
        value.append(contentsOf: nextValue())
    }
}

/// Marks a sideways-scrolling area so the tab's page swipe leaves its drags
/// alone. Harmless outside a paging tab (nothing reads the preference).
struct PageSwipeExempt: ViewModifier {
    func body(content: Content) -> some View {
        content.background(
            GeometryReader { proxy in
                Color.clear.preference(key: PageSwipeExemptKey.self,
                                       value: [proxy.frame(in: .named(PageSwipeSpace.name))])
            }
        )
    }
}

/// Swipe right anywhere on a pushed page to go back (Lucas 2026-10-13:
/// from anywhere, not just the edge — chosen knowing a long rightward drag
/// on a sideways chip row can also go back). The system bar is hidden
/// app-wide, which also turns off iOS's own edge swipe-back, so pushed
/// pages carry this instead: the page follows the finger and goes back
/// past 90pt or on a flick.
struct SwipeBack: ViewModifier {
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Resets on its own when the gesture ends OR is cancelled.
    @GestureState private var drag: CGFloat = 0
    private static func isBackSwipe(_ value: DragGesture.Value) -> Bool {
        let dx = value.translation.width, dy = value.translation.height
        return dx > 0 && dx > abs(dy) * 1.6
    }

    func body(content: Content) -> some View {
        content
            .offset(x: reduceMotion ? 0 : drag)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: drag == 0)
            .simultaneousGesture(
                DragGesture(minimumDistance: 12)
                    .updating($drag) { value, state, _ in
                        guard Self.isBackSwipe(value) else { return }
                        let dx = value.translation.width
                        state = dx / (1 + dx / 600)
                    }
                    .onEnded { value in
                        guard Self.isBackSwipe(value),
                              value.translation.width > 90 || value.predictedEndTranslation.width > 260 else { return }
                        action()
                    }
            )
    }
}

extension View {
    func inTabPageSwipe<Page: Hashable>(pages: [Page], selection: Binding<Page>, wraps: Bool = false) -> some View {
        modifier(InTabPageSwipe(pages: pages, selection: selection, wraps: wraps))
    }

    func swipeBack(_ action: @escaping () -> Void) -> some View {
        modifier(SwipeBack(action: action))
    }

    /// See PageSwipeExempt.
    func pageSwipeExempt() -> some View {
        modifier(PageSwipeExempt())
    }
}

// MARK: - Motion kit (reverse-engineered from the reference Shorts, 2026-10-15)
//
// The grammar both references share: every entrance and exit is blur +
// opacity; what the user would type is typed; a tapped thing pulses a
// ring; one word takes a colour sweep; a mode change is a circle growing
// out of what you touched. Every piece honours Reduce Motion by falling
// back to plain opacity. Pure SwiftUI; no timers outside `.task`.

struct BlurFade: ViewModifier {
    var blur: CGFloat
    var opacity: Double
    func body(content: Content) -> some View {
        content.blur(radius: blur).opacity(opacity)
    }
}

extension AnyTransition {
    /// The default entrance and exit: blurred and transparent → sharp and
    /// opaque. Under Reduce Motion the blur is skipped.
    static var blurIn: AnyTransition {
        if UIAccessibility.isReduceMotionEnabled { return .opacity }
        return .modifier(active: BlurFade(blur: 12, opacity: 0), identity: BlurFade(blur: 0, opacity: 1))
    }
}

/// Reveals text one character at a time, the way a person types (~13
/// characters a second), with a caret while it runs. Reduce Motion shows
/// the whole line at once.
struct TypewriterText: View {
    let text: String
    var charactersPerSecond: Double = 13
    var startDelay: TimeInterval = 0
    var showsCaret = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = 0

    var body: some View {
        let done = shown >= text.count
        Text(String(text.prefix(shown)) + (showsCaret && !done ? "|" : ""))
            .task(id: text) {
                if reduceMotion { shown = text.count; return }
                shown = 0
                if startDelay > 0 { try? await Task.sleep(for: .seconds(startDelay)) }
                for index in 1...max(1, text.count) {
                    try? await Task.sleep(for: .seconds(1 / charactersPerSecond))
                    guard !Task.isCancelled else { return }
                    shown = index
                }
            }
            .accessibilityLabel(text)
    }
}

/// A thin ring that grows out past its frame and fades — the logo reveal,
/// the send-button pulse, the "ready" radiation. Repeats when asked.
struct RingPulse: View {
    var color: Color = MorpheTheme.accent
    var lineWidth: CGFloat = 1.5
    var from: CGFloat = 0.3
    var to: CGFloat = 2.6
    var duration: TimeInterval = 1.1
    var delay: TimeInterval = 0
    var repeats = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var grown = false

    var body: some View {
        Circle()
            .stroke(color.opacity(0.6), lineWidth: lineWidth)
            .scaleEffect(grown ? to : from)
            .opacity(grown ? 0 : 1)
            .onAppear {
                guard !reduceMotion else { return }
                let base = Animation.easeOut(duration: duration).delay(delay)
                withAnimation(repeats ? base.repeatForever(autoreverses: false) : base) { grown = true }
            }
            .accessibilityHidden(true)
    }
}

/// One word takes a colour sweep from left to right ("Train HONEST.").
struct SweepWord: View {
    let word: String
    var font: Font = .largeTitle.weight(.bold)
    var color: Color = MorpheTheme.accent
    var delay: TimeInterval = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1

    var body: some View {
        Text(word)
            .font(font)
            .overlay(
                GeometryReader { geo in
                    LinearGradient(colors: [.clear, color, color, .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: geo.size.width * 1.4)
                        .offset(x: phase * geo.size.width * 1.2 - geo.size.width * 0.2)
                        .mask(Text(word).font(font))
                }
            )
            .onAppear {
                if reduceMotion { phase = 0; return }
                withAnimation(.easeInOut(duration: 1.0).delay(delay)) { phase = 1 }
            }
    }
}

/// A circle grows out of a point until the whole content shows — the way
/// the dark voice stage opens from the card you tapped. `revealed` false
/// hides the content behind a dot at `origin`.
struct RadialReveal<Content: View>: View {
    var origin: UnitPoint = .center
    var revealed: Bool
    var duration: TimeInterval = 0.6
    @ViewBuilder var content: () -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            content().opacity(revealed ? 1 : 0).animation(.easeInOut(duration: duration), value: revealed)
        } else {
            content()
                .mask(
                    GeometryReader { geo in
                        let side = max(geo.size.width, geo.size.height) * 2.4
                        Circle()
                            .frame(width: side, height: side)
                            .scaleEffect(revealed ? 1 : 0.004)
                            .position(x: origin.x * geo.size.width, y: origin.y * geo.size.height)
                    }
                )
                .animation(.easeInOut(duration: duration), value: revealed)
        }
    }
}

/// Runs `beats` once, each after its delay, so a sequence of blur-ins can
/// be written as data: `[0, 0.25, 0.5]` → three `shown` flags.
struct BeatSequence<Content: View>: View {
    let delays: [TimeInterval]
    @ViewBuilder let content: ([Bool]) -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: [Bool] = []

    var body: some View {
        content(shown.count == delays.count ? shown : Array(repeating: false, count: delays.count))
            .task {
                if reduceMotion { shown = Array(repeating: true, count: delays.count); return }
                shown = Array(repeating: false, count: delays.count)
                for (index, delay) in delays.enumerated() {
                    try? await Task.sleep(for: .seconds(max(0, delay - (index > 0 ? delays[index - 1] : 0))))
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeOut(duration: 0.45)) { shown[index] = true }
                }
            }
    }
}

/// The finish sequence (feedback audit 2026-10-16, F2): the publish moment,
/// played as beats with hit-stops between them — summary rises (0 ms),
/// the streak lands (+500), PRs stamp in one by one (+500 each), then it
/// settles and the record stamp (if any) takes the stage. HUD language:
/// ink, mono, hairlines; no confetti. Tap anywhere to skip ahead.
struct FinishSequenceOverlay: View {
    let moment: FinishSequenceMoment
    let onDismiss: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 0 = nothing, 1 = summary, 2 = streak, 3+ = PR rows.
    @State private var beat = 0
    @State private var runner: Task<Void, Never>?

    private var totalBeats: Int { 2 + moment.prNames.count }

    var body: some View {
        ZStack {
            MorpheTheme.ink.opacity(0.82).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 18) {
                Text(moment.shortDay ? "SHORT DAY LOGGED" : "SESSION LOGGED")
                    .font(MorpheTheme.microLabel(11)).tracking(2.2)
                    .foregroundStyle(MorpheTheme.accentText)
                Text(moment.workoutName)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(MorpheTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(moment.statsLine)
                    .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                    .foregroundStyle(MorpheTheme.textSecondary)

                if beat >= 2 {
                    HStack(spacing: 10) {
                        Image(systemName: "flame.fill")
                            .font(.headline)
                            .foregroundStyle(MorpheTheme.accentText)
                            .symbolEffect(.bounce, value: beat)
                        Text("\(moment.streakDays)")
                            .font(.title3.weight(.bold)).monospacedDigit()
                            .foregroundStyle(MorpheTheme.textPrimary)
                            .contentTransition(.numericText(value: Double(moment.streakDays)))
                        Text(moment.streakDays == 1 ? "DAY STREAK" : "DAY STREAK")
                            .font(MorpheTheme.microLabel(10)).tracking(1.4)
                            .foregroundStyle(MorpheTheme.textSecondary)
                    }
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                }

                ForEach(Array(moment.prNames.enumerated()), id: \.offset) { index, name in
                    if beat >= 3 + index {
                        HStack(spacing: 10) {
                            Image(systemName: "trophy.fill")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(MorpheTheme.accentText)
                            Text("NEW PR · \(name.uppercased())")
                                .font(MorpheTheme.microLabel(11)).tracking(1.2)
                                .foregroundStyle(MorpheTheme.textPrimary)
                        }
                        .transition(reduceMotion ? .opacity : .scale(scale: 1.25).combined(with: .opacity))
                    }
                }

                Button("Continue", action: finish)
                    .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                    .padding(.top, 6)
                    .opacity(beat >= totalBeats ? 1 : 0.35)
            }
            .padding(24)
            .frame(maxWidth: 420)
            .background(
                RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                    .fill(MorpheTheme.ink.opacity(0.98))
            )
            .overlay(
                RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                    .stroke(MorpheTheme.accent.opacity(0.45), lineWidth: 1)
            )
            .padding(.horizontal, 20)
            .scaleEffect(beat == 0 && !reduceMotion ? 0.94 : 1)
            .opacity(beat == 0 ? 0 : 1)
        }
        .contentShape(Rectangle())
        .onTapGesture { if beat < totalBeats { skipToEnd() } }
        .animation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.38, dampingFraction: 0.78), value: beat)
        .onAppear(perform: run)
        .onDisappear { runner?.cancel() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(moment.workoutName) logged. \(moment.statsLine). \(moment.streakDays) day streak."
                            + (moment.prNames.isEmpty ? "" : " New records: \(moment.prNames.joined(separator: ", "))."))
    }

    private func run() {
        runner = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            beat = 1
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            beat = 2
            Haptics.impact(.medium)
            for _ in moment.prNames {
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }
                beat += 1
                // The stamp that follows owns the PR chord; here the
                // row lands with a heavy strike only.
                Haptics.impact(.heavy)
            }
            // Settle, then hand off (the stamp or Today's done card).
            try? await Task.sleep(for: .seconds(moment.prNames.isEmpty ? 2.2 : 2.8))
            guard !Task.isCancelled else { return }
            onDismiss()
        }
    }

    private func skipToEnd() {
        runner?.cancel()
        beat = totalBeats
        runner = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            onDismiss()
        }
    }

    private func finish() {
        runner?.cancel()
        onDismiss()
    }
}


/// One layout editor for any page's sections (Lucas 2026-10-16): drag to
/// reorder, eye to hide. Today and Train keep their own editors; Discover
/// and Learn use this.
struct LayoutEditorSheet<Card: LayoutCard>: View {
    let title: String
    let header: String
    let layout: [Card]
    let hidden: [String]
    let onHidden: ([String]) -> Void
    let onOrder: ([String]) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(layout) { card in
                        let isHidden = hidden.contains(card.rawValue)
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(card.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(MorpheTheme.textPrimary)
                                Text(card.detail)
                                    .font(.caption)
                                    .foregroundStyle(MorpheTheme.textMuted)
                            }
                            Spacer()
                            Button {
                                var set = hidden
                                if isHidden { set.removeAll { $0 == card.rawValue } } else { set.append(card.rawValue) }
                                onHidden(set)
                                Haptics.selection()
                            } label: {
                                Image(systemName: isHidden ? "eye.slash" : "eye")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(isHidden ? MorpheTheme.textMuted : MorpheTheme.accentText)
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel(isHidden ? "Show \(card.title)" : "Hide \(card.title)")
                        }
                        .listRowBackground(MorpheTheme.inkAlt)
                    }
                    .onMove { from, to in
                        var order = layout
                        order.move(fromOffsets: from, toOffset: to)
                        onOrder(order.map(\.rawValue))
                        Haptics.selection()
                    }
                } header: {
                    Text(header)
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textMuted)
                }
            }
            .scrollContentBackground(.hidden)
            .background(MorpheTheme.ink)
            .environment(\.editMode, .constant(.active))
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(MorpheTheme.accentText)
                }
            }
        }
    }
}

/// The quiet "Edit X's layout" footer every editable page ends with.
struct EditLayoutButton: View {
    let page: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Edit \(page)'s layout", systemImage: "slider.horizontal.3")
                .font(.caption.weight(.semibold))
                .foregroundStyle(MorpheTheme.textMuted)
                .frame(minHeight: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Edit \(page)'s layout — reorder or hide sections")
    }
}

// MARK: - In-place layout editor (Lucas 2026-10-16)
//
// No pop-up: "Edit X's layout" puts the page itself into editor mode.
// Every section gets an eye (tap → it pops out, with a tap you feel), and
// a hold lifts it (a buzz) so it can be dragged up or down the page; the
// order is saved the moment it's dropped. Nothing can be lost: hidden
// sections wait in a HIDDEN row at the bottom with a Show button, and the
// last visible section can't be hidden.

enum EditablePage: String { case today, train, discover, explore, learn, board, chats, calendar, nutrition, library
    /// Discover's sections are Fitness and Explore (Lucas 2026-10-16);
    /// Learn's first section is Lessons (Lucas 2026-10-17).
    var title: String {
        switch self {
        case .discover: return "Fitness"
        case .learn: return "Lessons"
        default: return rawValue.capitalized
        }
    }
}

/// Frames of every section in the editor's coordinate space.
struct EditorFrameKey: PreferenceKey {
    static var defaultValue: [AnyHashable: CGRect] = [:]
    static func reduce(value: inout [AnyHashable: CGRect], nextValue: () -> [AnyHashable: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

/// The banner at the top of a page in editor mode.
struct EditorModeBar: View {
    let tab: ClientTab
    /// The page in edit (nil on a tab with nothing to arrange).
    var page: EditablePage? = nil
    /// False on a page with no layout to arrange (Network).
    let editable: Bool
    let onDone: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "slider.horizontal.3")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(MorpheTheme.onFill(MorpheTheme.accent))
            VStack(alignment: .leading, spacing: 1) {
                Text("EDITING \((page?.title ?? tab.title).uppercased())")
                    .font(MorpheTheme.microLabel(10)).tracking(1.6)
                    .foregroundStyle(MorpheTheme.onFill(MorpheTheme.accent))
                Text(!editable ? "Nothing to arrange here · hold a tab below to move it"
                     : (page == .today ? "Hold a box to lift it, then slide · tap the eye to hide it · the pinned boxes hide only"
                        : "Hold a box to lift it, then slide · tap the eye to hide it · hold a tab to move it"))
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.onFill(MorpheTheme.accent).opacity(0.85))
            }
            Spacer(minLength: 8)
            Button("Done", action: onDone)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(MorpheTheme.accent)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(MorpheTheme.onFill(MorpheTheme.accent)))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous).fill(MorpheTheme.accent))
        .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
        .accessibilityElement(children: .contain)
    }
}

/// The reorderable, hideable list of a page's sections.
struct SectionEditorList<Card: Hashable & Identifiable, Content: View>: View {
    let editing: Bool
    /// Visible cards in order.
    let cards: [Card]
    /// Hidden cards, for the HIDDEN row.
    let hidden: [Card]
    let title: (Card) -> String
    /// New visible order (hidden cards keep their place in the saved list).
    let onMove: ([Card]) -> Void
    let onHide: (Card) -> Void
    let onShow: (Card) -> Void
    @ViewBuilder let content: (Card) -> Content

    @Environment(MorpheAppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var frames: [AnyHashable: CGRect] = [:]
    @State private var lifted: Card? = nil
    @State private var fingerY: CGFloat = 0
    @State private var popping: Card? = nil
    @State private var shaking: Card? = nil
    /// Finger down on a box, before the hold completes.
    @State private var pressing: Card? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(cards) { card in
                let isLifted = lifted == card
                content(card)
                    // The box's own controls sleep in editor mode; the hold
                    // view below is not affected (it is a sibling overlay).
                    .allowsHitTesting(!editing)
                    .overlay {
                        // Hold the box to lift it, keep holding to slide it
                        // (Lucas 2026-10-16). A UIKit long press, so the page
                        // still scrolls — the home-screen pattern.
                        if editing {
                            HoldDragOverlay(
                                onPress: { down in pressing = down ? card : nil },
                                onLift: {
                                    lifted = card
                                    fingerY = frames[AnyHashable(card)]?.midY ?? 0
                                    Haptics.impact(.medium)
                                },
                                onMove: { point in
                                    guard lifted == card else { return }
                                    fingerY = point.y
                                    reorderIfNeeded(card)
                                },
                                onDrop: {
                                    if lifted != nil { Haptics.impact(.light) }
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { lifted = nil }
                                }
                            )
                            .padding(.trailing, 52)   // the eye stays tappable
                        }
                    }
                    .overlay(alignment: .topTrailing) { if editing { eye(for: card) } }
                    .overlay {
                        if editing {
                            RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                                .foregroundStyle(MorpheTheme.accent.opacity(isLifted ? 0.9 : (pressing == card ? 0.8 : 0.45)))
                                .allowsHitTesting(false)
                        }
                    }
                    // Charging: a slight press-in while the hold counts,
                    // then the lift (late audit 2026-10-16, #4).
                    .scaleEffect(popping == card ? 0.001 : (isLifted && !reduceMotion ? 1.03 : (pressing == card && !reduceMotion ? 0.98 : 1)))
                    .animation(.easeOut(duration: 0.25), value: pressing)
                    .opacity(popping == card ? 0 : 1)
                    .offset(x: shaking == card ? 8 : 0)
                    .offset(y: isLifted ? fingerY - (frames[AnyHashable(card)]?.midY ?? fingerY) : 0)
                    .shadow(color: .black.opacity(isLifted ? 0.28 : 0), radius: 14, y: 8)
                    .zIndex(isLifted ? 2 : 0)
                    .background(GeometryReader { geo in
                        Color.clear.preference(key: EditorFrameKey.self, value: [AnyHashable(card): geo.frame(in: .global)])
                    })
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: lifted)
                    .accessibilityAction(named: "Hide \(title(card))") { hide(card) }
                    // VoiceOver can't hold-and-slide (persona audit #5):
                    // Move up / Move down do the same reorder.
                    .accessibilityAction(named: "Move \(title(card)) up") { nudge(card, by: -1) }
                    .accessibilityAction(named: "Move \(title(card)) down") { nudge(card, by: 1) }
            }
            if editing, !hidden.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("HIDDEN")
                        .font(MorpheTheme.microLabel(10)).tracking(1.4)
                        .foregroundStyle(MorpheTheme.textMuted)
                    WrapStack(spacing: 8) {
                        ForEach(hidden) { card in
                            Button {
                                onShow(card)
                                Haptics.impact(.light)
                            } label: {
                                Label("Show \(title(card))", systemImage: "eye")
                                    .font(.caption.weight(.semibold))
                            }
                            .buttonStyle(FilterChipStyle(isSelected: false, selectedColor: MorpheTheme.accent))
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .onPreferenceChange(EditorFrameKey.self) { frames = $0 }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: cards)
    }

    private func eye(for card: Card) -> some View {
        Button {
            hide(card)
        } label: {
            Image(systemName: "eye.slash")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(MorpheTheme.onFill(MorpheTheme.accent))
                .frame(width: 36, height: 36)
                .background(Circle().fill(MorpheTheme.accent))
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .padding(8)
        .accessibilityLabel("Hide \(title(card))")
    }

    private func hide(_ card: Card) {
        guard cards.count > 1 else {
            // The last box on a page can't go: a shake, a buzz, one line.
            Haptics.error()
            store.showToast("Keep at least one section on this page.")
            withAnimation(.default.speed(3).repeatCount(3, autoreverses: true)) { shaking = card }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(260))
                shaking = nil
            }
            return
        }
        // The quick pop (Lucas): it shrinks away with a rigid tap.
        Haptics.impact(.rigid)
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.25, dampingFraction: 0.7)) { popping = card }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(220))
            onHide(card)
            popping = nil
        }
    }

    private func nudge(_ card: Card, by delta: Int) {
        guard let from = cards.firstIndex(of: card) else { return }
        let to = from + delta
        guard cards.indices.contains(to) else { return }
        var next = cards; next.swapAt(from, to)
        Haptics.selection()
        onMove(next)
    }

    private func reorderIfNeeded(_ card: Card) {
        guard let from = cards.firstIndex(of: card) else { return }
        // The dragged box belongs before the first other box whose middle
        // is below the finger.
        let others = cards.filter { $0 != card }
        let target = others.filter { (frames[AnyHashable($0)]?.midY ?? .infinity) < fingerY }.count
        guard target != from else { return }
        var next = others
        next.insert(card, at: target)
        Haptics.selection()
        onMove(next)
    }
}

/// The tab bar's order, edited by holding an icon and dragging it along
/// the strip; shown above the bar while any page is in editor mode.
/// Editor mode's tab bar (Lucas 2026-10-16): it stands in for the system
/// bar while editing. Tap switches tabs; hold a tab to lift it and slide
/// it left or right inside the bubble; the order saves on drop.
struct TabOrderStrip: View {
    @Environment(MorpheAppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var frames: [AnyHashable: CGRect] = [:]
    @State private var lifted: ClientTab? = nil
    @State private var pressing: ClientTab? = nil
    @State private var fingerX: CGFloat = 0

    var body: some View {
        HStack(spacing: 0) {
            ForEach(store.tabLayout) { tab in
                let isLifted = lifted == tab
                let isSelected = store.selectedClientTab == tab
                VStack(spacing: 3) {
                    Image(systemName: tab.systemImage)
                        .font(.title3.weight(.semibold))
                    Text(tab.title)
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(isLifted || isSelected ? MorpheTheme.accentText : MorpheTheme.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(
                    Capsule(style: .continuous)
                        .fill(MorpheTheme.accent.opacity(isLifted ? 0.22 : (pressing == tab ? 0.12 : 0)))
                        .padding(.horizontal, 2)
                )
                .scaleEffect(isLifted && !reduceMotion ? 1.12 : (pressing == tab && !reduceMotion ? 0.94 : 1))
                .animation(.easeOut(duration: 0.25), value: pressing)
                .offset(x: isLifted ? fingerX - (frames[AnyHashable(tab)]?.midX ?? fingerX) : 0)
                .shadow(color: .black.opacity(isLifted ? 0.3 : 0), radius: 10, y: 4)
                .zIndex(isLifted ? 2 : 0)
                .background(GeometryReader { geo in
                    Color.clear.preference(key: EditorFrameKey.self, value: [AnyHashable(tab): geo.frame(in: .global)])
                })
                .overlay {
                    HoldDragOverlay(
                        onTap: { store.selectedClientTab = tab },
                        onPress: { down in pressing = down ? tab : nil },
                        onLift: {
                            lifted = tab
                            fingerX = frames[AnyHashable(tab)]?.midX ?? 0
                            Haptics.impact(.medium)
                        },
                        onMove: { point in
                            guard lifted == tab else { return }
                            // The icon stays inside the bubble.
                            let xs = frames.values.map(\.midX)
                            fingerX = min(max(point.x, xs.min() ?? point.x), xs.max() ?? point.x)
                            reorderIfNeeded(tab)
                        },
                        onDrop: {
                            if lifted != nil { Haptics.impact(.light) }
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { lifted = nil }
                        }
                    )
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: lifted)
                .accessibilityLabel("\(tab.title) tab")
                .accessibilityAction(named: "Move \(tab.title) left") { nudgeTab(tab, by: -1) }
                .accessibilityAction(named: "Move \(tab.title) right") { nudgeTab(tab, by: 1) }
            }
        }
        .onPreferenceChange(EditorFrameKey.self) { frames = $0 }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: store.tabLayout)
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Capsule(style: .continuous).fill(.ultraThinMaterial))
        .overlay(Capsule(style: .continuous).stroke(MorpheTheme.accent.opacity(0.5), lineWidth: 1))
        .padding(.horizontal, 16)
    }

    private func nudgeTab(_ tab: ClientTab, by delta: Int) {
        var order = store.tabLayout
        guard let from = order.firstIndex(of: tab), order.indices.contains(from + delta) else { return }
        order.swapAt(from, from + delta)
        Haptics.selection()
        store.setTabOrder(order.map(\.rawValue))
    }

    private func reorderIfNeeded(_ tab: ClientTab) {
        let order = store.tabLayout
        guard let from = order.firstIndex(of: tab) else { return }
        let others = order.filter { $0 != tab }
        let target = others.filter { (frames[AnyHashable($0)]?.midX ?? .infinity) < fingerX }.count
        guard target != from else { return }
        var next = others; next.insert(tab, at: target)
        Haptics.selection()
        store.setTabOrder(next.map(\.rawValue))
    }
}

/// Hold to lift, keep holding to move (Lucas 2026-10-16). A UIKit long
/// press so it lives beside the page's scroll instead of swallowing it;
/// the point is in window (SwiftUI `.global`) coordinates. While a box is
/// lifted the enclosing scroll view is frozen so the slide doesn't scroll.
struct HoldDragOverlay: UIViewRepresentable {
    /// The hold before a box lifts — Lucas asked for a deliberate hold.
    static let holdSeconds: TimeInterval = 2.0

    var onTap: (() -> Void)? = nil
    /// Finger down / up, before the hold completes (late audit
    /// 2026-10-16, #4): the box shows it is charging.
    var onPress: ((Bool) -> Void)? = nil
    let onLift: () -> Void
    let onMove: (CGPoint) -> Void
    let onDrop: () -> Void

    /// A view that reports raw touch down/up.
    final class PressView: UIView {
        var onPress: ((Bool) -> Void)?
        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) { super.touchesBegan(touches, with: event); onPress?(true) }
        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { super.touchesEnded(touches, with: event); onPress?(false) }
        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { super.touchesCancelled(touches, with: event); onPress?(false) }
    }

    func makeUIView(context: Context) -> UIView {
        let view = PressView()
        view.onPress = { [weak coordinator = context.coordinator] down in coordinator?.parent.onPress?(down) }
        view.backgroundColor = nil
        view.isOpaque = false
        let hold = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleHold(_:)))
        hold.minimumPressDuration = Self.holdSeconds
        hold.allowableMovement = 12
        view.addGestureRecognizer(hold)
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap))
        view.addGestureRecognizer(tap)
        return view
    }

    func updateUIView(_ view: UIView, context: Context) { context.coordinator.parent = self }
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject {
        var parent: HoldDragOverlay
        private weak var frozenScroll: UIScrollView?
        init(_ parent: HoldDragOverlay) { self.parent = parent }

        @objc func handleTap() { parent.onTap?() }

        @objc func handleHold(_ gesture: UILongPressGestureRecognizer) {
            let point = gesture.location(in: nil)
            switch gesture.state {
            case .began:
                var ancestor = gesture.view?.superview
                while let view = ancestor, !(view is UIScrollView) { ancestor = view.superview }
                if let scroll = ancestor as? UIScrollView { scroll.isScrollEnabled = false; frozenScroll = scroll }
                parent.onLift()
                parent.onMove(point)
            case .changed:
                parent.onMove(point)
            case .ended, .cancelled, .failed:
                frozenScroll?.isScrollEnabled = true
                frozenScroll = nil
                parent.onDrop()
            default: break
            }
        }
    }
}


/// An eye on a pinned (non-reorderable) box in editor mode.
private struct EditorEye: ViewModifier {
    let editing: Bool
    let title: String
    let compact: Bool
    let onHide: () -> Void
    @State private var popping = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay {
                if editing {
                    RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                        .foregroundStyle(MorpheTheme.accent.opacity(0.45))
                        .allowsHitTesting(false)
                }
            }
            .overlay(alignment: .topTrailing) {
                if editing {
                    Button {
                        Haptics.impact(.rigid)
                        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.25, dampingFraction: 0.7)) { popping = true }
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(220))
                            onHide(); popping = false
                        }
                    } label: {
                        Image(systemName: "eye.slash")
                            .font((compact ? Font.caption : .subheadline).weight(.bold))
                            .foregroundStyle(MorpheTheme.onFill(MorpheTheme.accent))
                            .frame(width: compact ? 28 : 36, height: compact ? 28 : 36)
                            .background(Circle().fill(MorpheTheme.accent))
                            .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                    }
                    .buttonStyle(.plain)
                    .padding(compact ? 4 : 8)
                    .accessibilityLabel("Hide \(title)")
                }
            }
            .scaleEffect(popping ? 0.001 : 1)
            .opacity(popping ? 0 : 1)
            .allowsHitTesting(!editing || true)
    }
}

extension View {
    func editorEye(_ editing: Bool, title: String, compact: Bool = false, onHide: @escaping () -> Void) -> some View {
        modifier(EditorEye(editing: editing, title: title, compact: compact, onHide: onHide))
    }
}
