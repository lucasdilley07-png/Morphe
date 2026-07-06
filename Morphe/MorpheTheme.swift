import SwiftUI
import UIKit

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
    static let textMuted = Color.white.opacity(0.44)
    static let stroke = Color.white.opacity(0.10)
    static let strokeSubtle = Color.white.opacity(0.05)
    static let warning = Color(red: 0.98, green: 0.70, blue: 0.25)         // amber, distinct from accent
    static let danger = Color(red: 0.95, green: 0.36, blue: 0.36)
    static let lavender = Color(red: 0.72, green: 0.72, blue: 0.74)        // neutral (no off-brand purple)
    private static var currentAccentPalette: AccentPalette = .gold

    /// HUD corner radius — sharp, technical. One knob for the whole system.
    static let radius: CGFloat = 3

    /// Monospaced micro-label — the telemetry signature. Pair with
    /// `.tracking(1.4)` and an uppercased string.
    static func microLabel(_ size: CGFloat = 11) -> Font {
        .system(size: size, design: .monospaced).weight(.semibold)
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

    /// MORPHE signature yellow (#FFD600). The brand is single-accent, so this is
    /// locked rather than driven by the legacy accent-palette picker.
    static let brandYellow = Color(red: 1.0, green: 0.839, blue: 0.0)      // #FFD600
    static let brandGold = Color(red: 0.95, green: 0.72, blue: 0.0)        // deeper gold for gradients

    static var accent: Color { brandYellow }

    static var accentAlt: Color { brandGold }

    static func apply(accentPalette: AccentPalette) {
        currentAccentPalette = accentPalette
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
            .textCase(.uppercase)
            .font(.system(.subheadline, design: .monospaced).weight(.bold))
            .tracking(1.2)
            .foregroundStyle(.black)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                    .fill(accent.opacity(configuration.isPressed ? 0.78 : 1))
            )
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct SecondaryCTAButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .textCase(.uppercase)
            .font(.system(.subheadline, design: .monospaced).weight(.bold))
            .tracking(1.2)
            .foregroundStyle(configuration.isPressed ? MorpheTheme.textSecondary : .white)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                    .fill(configuration.isPressed ? MorpheTheme.panelStrong : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
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
