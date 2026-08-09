import SwiftUI
import UIKit
import AVFoundation

enum MorpheTheme {
    // MORPHE telemetry palette — flat black + #FFD600 yellow. HUD language:
    // flat surfaces, hairline strokes, monospaced micro-labels; no glass
    // gradients, no glows. Yellow is scarce — primary action + key data.
    static let ink = Color(red: 0.020, green: 0.020, blue: 0.024)          // flat near-black base
    static let inkAlt = Color(red: 0.043, green: 0.043, blue: 0.047)
    static let panel = Color.white.opacity(0.035)                          // flat surface tints
    static let panelStrong = Color.white.opacity(0.06)
    static let panelRaised = Color.white.opacity(0.085)
    static let panelInteractive = Color.white.opacity(0.13)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.66)
    static let textMuted = Color.white.opacity(0.56)
    static let stroke = Color.white.opacity(0.10)
    static let strokeSubtle = Color.white.opacity(0.05)
    static let warning = Color(red: 0.98, green: 0.70, blue: 0.25)         // amber, distinct from accent
    static let danger = Color(red: 0.95, green: 0.36, blue: 0.36)
    static let lavender = Color(red: 0.72, green: 0.72, blue: 0.74)        // neutral (no off-brand purple)
    private static var currentAccentPalette: AccentPalette = .gold

    /// HUD corner radius — sharp, technical. One knob for the whole system.
    // Hims-audit revamp (2026-08-09): soft, calm geometry. The hard 3pt
    // HUD edge read as technical; 16pt reads as considered. One token —
    // every card, field, tile, and sheet in the app follows.
    static let radius: CGFloat = 16

    /// Chip/badge radius — the deliberate second, tighter knob the small
    /// elements already used as a literal `2` in a dozen places.
    // Softened with the revamp — hard 2pt chips fought the 16pt cards.
    static let chipRadius: CGFloat = 8

    /// Spacing scale — a 4pt grid for the whole HUD. New code uses these;
    /// existing literals migrate as files get touched. (The audit counted
    /// 600+ magic spacing numbers; the token is how that stops growing.)
    enum Spacing {
        /// 4 — hairline gaps inside a label stack.
        static let xs: CGFloat = 4
        /// 8 — chip rows, tight control clusters.
        static let sm: CGFloat = 8
        /// 12 — default gap inside a card.
        static let md: CGFloat = 12
        /// 16 — card-to-card, screen gutters.
        static let lg: CGFloat = 16
        /// 20 — horizontal screen padding.
        static let xl: CGFloat = 20
        /// 24 — section breaks.
        static let xxl: CGFloat = 24
        /// 36 — where page content starts below the floating header icons.
        /// One knob for every tab landing (athlete shell).
        static let pageTop: CGFloat = 36
        // Hand-tuned per-surface page tops (Lucas's on-device pass,
        // 2026-07-28): tabs whose roots sit in a NavigationStack consume
        // the shell's top safe-area inset differently than plain scrolls,
        // so ONE constant rendered six different gaps. Targets below aim
        // every tab at the same visual start line under the icon row —
        // adjust these four, never per-view literals.
        static let pageTopToday: CGFloat = 48
        static let pageTopTrain: CGFloat = 60
        static let pageTopStacked: CGFloat = 60   // Discover, Network
        // Matches pageTopStacked — these pages open with title text, and
        // anything shorter leaves it under the floating avatar button.
        static let pageTopCompact: CGFloat = 60   // Progress, Learn
    }

    /// Monospaced micro-label — the telemetry signature. Pair with
    /// `.tracking(1.4)` and an uppercased string.
    /// Scaled: the point size rides Dynamic Type via UIFontMetrics (at the
    /// default setting it IS the requested size, so the HUD look is
    /// untouched; at accessibility sizes the labels finally grow with the
    /// body text instead of staying microscopic).
    static func microLabel(_ size: CGFloat = 11) -> Font {
        let scaled = UIFontMetrics(forTextStyle: .caption2).scaledValue(for: size)
        return .system(size: scaled, design: .monospaced).weight(.semibold)
    }

    // Glows retired with the glass design; kept near-zero for API compat.
    static var glow: Color {
        accent.opacity(0.05)
    }

    static var glowAlt: Color {
        accentAlt.opacity(0.04)
    }

    static var strokeStrong: Color {
        accent.opacity(0.30)
    }

    static var HUDGradient: LinearGradient {
        LinearGradient(colors: [panel, panel], startPoint: .top, endPoint: .bottom)
    }

    /// MORPHE signature yellow (#FFD600). Single-accent by default: `.gold`
    /// (the default palette) resolves to this brand pair, so the app ships
    /// looking exactly on-brand. Users can personalize via the accent picker,
    /// which swaps `accent`/`accentAlt` to that palette's pair app-wide.
    static let brandYellow = Color(red: 1.0, green: 0.839, blue: 0.0)      // #FFD600
    static let brandGold = Color(red: 0.95, green: 0.72, blue: 0.0)        // deeper gold for gradients

    /// The launch M + app-icon color. Always brand yellow, regardless of the
    /// user's accent palette — the launch beat must match the app icon.
    static var launchMark: Color { brandYellow }

    static var accent: Color {
        currentAccentPalette == .gold ? brandYellow : colors(for: currentAccentPalette).primary
    }

    static var accentAlt: Color {
        currentAccentPalette == .gold ? brandGold : colors(for: currentAccentPalette).secondary
    }

    /// The resolved color behind AccentPalette.custom for THIS profile.
    /// Set through apply(accentPalette:customHex:) — defaults to gold.
    private(set) static var customAccentColor: Color = brandYellow

    static func apply(accentPalette: AccentPalette, customHex: String = "") {
        currentAccentPalette = accentPalette
        customAccentColor = color(fromHex: customHex) ?? brandYellow
    }

    /// "#RRGGBB" (leading # optional) → Color. Nil on anything malformed —
    /// callers fall back to gold rather than guessing.
    static func color(fromHex raw: String) -> Color? {
        var hex = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.count == 6, let value = UInt64(hex, radix: 16) else { return nil }
        return Color(
            red: Double((value >> 16) & 0xFF) / 255.0,
            green: Double((value >> 8) & 0xFF) / 255.0,
            blue: Double(value & 0xFF) / 255.0
        )
    }

    /// Color → "#RRGGBB" for persistence + the wire (posts carry it).
    static func hex(from color: Color) -> String {
        let ui = UIColor(color)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        ui.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        func byte(_ component: CGFloat) -> Int { Int((max(0, min(1, component)) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(red), byte(green), byte(blue))
    }

    /// Identity color for a feed author's self-declared accent id (the
    /// `authorAccent` riding their posts): a "#RRGGBB" hex renders as-is,
    /// a palette name maps to its primary. Unknown/empty → brand gold, so
    /// old posts and tampered values degrade to the default, never crash.
    /// A foreign "Custom" id is gold too — another athlete's custom hex
    /// travels ON their posts, never through this device's setting.
    static func accentColor(forPaletteId id: String) -> Color {
        if let hexColor = color(fromHex: id) { return hexColor }
        guard let palette = AccentPalette(rawValue: id), palette != .custom else { return brandYellow }
        return colors(for: palette).primary
    }

    static func colors(for accentPalette: AccentPalette) -> (primary: Color, secondary: Color) {
        switch accentPalette {
        case .electricBlue:
            return (
                Color(red: 0.42, green: 0.86, blue: 0.98),
                Color(red: 0.33, green: 0.63, blue: 1.00)
            )
        case .green:
            return (
                Color(red: 0.52, green: 0.95, blue: 0.60),
                Color(red: 0.28, green: 0.78, blue: 0.46)
            )
        case .red:
            return (
                Color(red: 0.98, green: 0.43, blue: 0.43),
                Color(red: 0.76, green: 0.22, blue: 0.28)
            )
        case .orange:
            return (
                Color(red: 0.98, green: 0.66, blue: 0.28),
                Color(red: 0.95, green: 0.46, blue: 0.18)
            )
        case .purple:
            return (
                Color(red: 0.72, green: 0.58, blue: 0.98),
                Color(red: 0.46, green: 0.34, blue: 0.92)
            )
        case .pink:
            return (
                Color(red: 0.98, green: 0.54, blue: 0.78),
                Color(red: 0.90, green: 0.34, blue: 0.62)
            )
        case .gold:
            return (
                Color(red: 0.92, green: 0.80, blue: 0.42),
                Color(red: 0.76, green: 0.61, blue: 0.20)
            )
        case .recruiter:
            // The referral-earned palette: a teal no level unlocks.
            return (
                Color(red: 0.34, green: 0.93, blue: 0.84),
                Color(red: 0.12, green: 0.70, blue: 0.65)
            )
        case .custom:
            // Whatever the user picked; secondary is the same hue pulled
            // darker so the accent pair keeps its depth.
            let ui = UIColor(customAccentColor)
            var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
            ui.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
            let secondary = Color(uiColor: UIColor(
                hue: hue, saturation: saturation, brightness: max(0.25, brightness * 0.72), alpha: 1))
            return (customAccentColor, secondary)
        }
    }

    static func color(for risk: RiskLevel) -> Color {
        switch risk {
        case .low:
            return accent
        case .medium:
            return warning
        case .high:
            return danger
        }
    }

    static func color(for tier: HealthTier) -> Color {
        switch tier {
        case .thriving, .strong:
            return accent
        case .building:
            return accentAlt
        case .atRisk:
            return warning
        case .resetMode:
            return danger
        }
    }

    static func color(for status: RecoveryStatus) -> Color {
        switch status {
        case .ready:
            return accent
        case .moderate:
            return accentAlt
        case .takeItEasy:
            return warning
        case .recoveryRecommended, .coachReviewNeeded:
            return danger
        }
    }

    static func color(for sport: SportFocus) -> Color {
        switch sport {
        case .boxing, .mma, .wrestling:
            return warning
        case .soccer, .running, .track:
            return accent
        case .basketball, .football, .baseball, .tennis, .volleyball:
            return accentAlt
        case .swimming:
            return lavender
        default:
            return .white
        }
    }
}

// MARK: - Dynamic Type for fixed-size HUD typography
//
// The HUD language is built on precise point sizes, which SwiftUI never
// scales. `scaledFont` keeps the design sizes as the 1.0 baseline and
// scales them with the user's type setting — capped, so a maxed-out
// accessibility size grows the numerals ~40% instead of shattering the
// instrument layouts. Offscreen renders (share-card posters) keep raw
// .system sizes on purpose: they are images, not UI.

extension DynamicTypeSize {
    /// System-ish curve anchored at .large = 1.0, capped at 1.4.
    var morpheScale: CGFloat {
        switch self {
        case .xSmall: return 0.86
        case .small: return 0.92
        case .medium: return 0.96
        case .large: return 1.0
        case .xLarge: return 1.06
        case .xxLarge: return 1.12
        case .xxxLarge: return 1.18
        default: return 1.4   // accessibility sizes, capped
        }
    }
}

private struct ScaledSystemFont: ViewModifier {
    @Environment(\.dynamicTypeSize) private var typeSize
    let size: CGFloat
    let weight: Font.Weight
    let design: Font.Design

    func body(content: Content) -> some View {
        content.font(.system(size: size * typeSize.morpheScale, weight: weight, design: design))
    }
}

extension View {
    /// Dynamic-Type-aware replacement for `.font(.system(size:weight:design:))`.
    func scaledFont(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> some View {
        modifier(ScaledSystemFont(size: size, weight: weight, design: design))
    }
}

enum Haptics {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    /// Failure gets felt too — success-only feedback made silent network
    /// errors literally imperceptible.
    static func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
    }

    /// The light tick for choosing among options (filter chips, tabs) —
    /// the most common interaction in the app finally has a feel.
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
}

/// Two tiny UI sounds, synthesized in memory — no bundled audio assets.
/// `star` (a rising four-note sparkle) marks a COMPLETION: task, workout,
/// quiz. `ding` (one soft bell hit) marks a CONTRIBUTION: saving a workout,
/// posting, commenting, sharing a win, logging a workout. The `.ambient`
/// session mixes with the user's own music and respects the silent switch —
/// a gym app must never barge into someone's playlist.
enum SoundEffects {
    enum Cue {
        case star
        case ding
    }

    private static var players: [Cue: AVAudioPlayer] = [:]
    private static var sessionConfigured = false

    static func play(_ cue: Cue) {
        if !sessionConfigured {
            try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            sessionConfigured = true
        }
        if players[cue] == nil {
            players[cue] = try? AVAudioPlayer(data: waveData(for: cue))
            players[cue]?.prepareToPlay()
        }
        guard let player = players[cue] else { return }
        player.currentTime = 0
        player.play()
    }

    // MARK: - Synthesis

    private static let sampleRate = 44_100.0

    /// Each cue is a sum of decaying sine strikes (fundamental + two soft
    /// harmonics). The star staggers four notes up a major arpeggio; the
    /// ding is a single B5 bell hit.
    private static func waveData(for cue: Cue) -> Data {
        // (frequency Hz, start seconds, ring seconds)
        let notes: [(Double, Double, Double)]
        switch cue {
        case .star:
            notes = [
                (1046.50, 0.000, 0.30),   // C6
                (1318.51, 0.065, 0.30),   // E6
                (1567.98, 0.130, 0.32),   // G6
                (2093.00, 0.195, 0.38)    // C7
            ]
        case .ding:
            notes = [(987.77, 0.0, 0.40)] // B5
        }

        let total = notes.map { $0.1 + $0.2 }.max()! + 0.05
        let frameCount = Int(total * sampleRate)
        var samples = [Double](repeating: 0, count: frameCount)

        for (frequency, start, ring) in notes {
            let startFrame = Int(start * sampleRate)
            let ringFrames = Int(ring * sampleRate)
            for i in 0..<ringFrames where startFrame + i < frameCount {
                let t = Double(i) / sampleRate
                // 4ms attack so the strike doesn't click; exponential decay.
                let attack = min(t / 0.004, 1)
                let envelope = attack * exp(-t * 10)
                let phase = 2 * Double.pi * frequency * t
                let tone = sin(phase) + 0.35 * sin(2 * phase) + 0.12 * sin(3 * phase)
                samples[startFrame + i] += tone * envelope * 0.28
            }
        }

        return wav(from: samples)
    }

    /// Minimal 16-bit mono WAV wrapper around raw samples.
    private static func wav(from samples: [Double]) -> Data {
        var pcm = Data(capacity: samples.count * 2)
        for sample in samples {
            let clipped = Int16(max(-1, min(1, sample)) * 32_766)
            withUnsafeBytes(of: clipped.littleEndian) { pcm.append(contentsOf: $0) }
        }

        var data = Data()
        func append(_ value: UInt32) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        func append16(_ value: UInt16) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }

        data.append(contentsOf: Array("RIFF".utf8))
        append(UInt32(36 + pcm.count))
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8))
        append(16)                                   // fmt chunk size
        append16(1)                                  // PCM
        append16(1)                                  // mono
        append(UInt32(sampleRate))                   // sample rate
        append(UInt32(sampleRate * 2))               // byte rate
        append16(2)                                  // block align
        append16(16)                                 // bits per sample
        data.append(contentsOf: Array("data".utf8))
        append(UInt32(pcm.count))
        data.append(pcm)
        return data
    }
}

struct PremiumBackground: View {
    var body: some View {
        // Flat black with a faint engineering grid — the telemetry canvas.
        // No radial glows, no gradient washes: content carries the screen.
        ZStack {
            MorpheTheme.ink

            PerformanceGridOverlay()
                .opacity(0.35)
        }
        .ignoresSafeArea()
    }
}

struct PrimaryCTAButtonStyle: ButtonStyle {
    var accent: Color = MorpheTheme.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            // Hims grammar: sentence-case pill, humanist weight — a calm
            // "one obvious next step," not a shouted command.
            .font(.system(.body, design: .rounded).weight(.semibold))
            // Never hyphenate a button label — shrink to fit.
            .lineLimit(1)
            .minimumScaleFactor(0.55)
            .foregroundStyle(.black)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                Capsule(style: .continuous)
                    .fill(accent.opacity(configuration.isPressed ? 0.78 : 1))
            )
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct SecondaryCTAButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            // Same calm pill grammar as the primary — outlined, not filled.
            .font(.system(.body, design: .rounded).weight(.semibold))
            // Never hyphenate a button label — shrink to fit.
            .lineLimit(1)
            .minimumScaleFactor(0.55)
            .foregroundStyle(configuration.isPressed ? MorpheTheme.textSecondary : .white)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                Capsule(style: .continuous)
                    .fill(configuration.isPressed ? MorpheTheme.panelStrong : Color.clear)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            )
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct PerformanceGridOverlay: View {
    private let spacing: CGFloat = 46

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Path { path in
                    var x: CGFloat = 0
                    while x <= proxy.size.width {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: proxy.size.height))
                        x += spacing
                    }

                    var y: CGFloat = 0
                    while y <= proxy.size.height {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                        y += spacing
                    }
                }
                .stroke(MorpheTheme.strokeSubtle, lineWidth: 0.5)

                LinearGradient(
                    colors: [
                        Color.white.opacity(0.02),
                        .clear,
                        .clear,
                        Color.white.opacity(0.03)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .blendMode(.screen)
    }
}
