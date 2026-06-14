import SwiftUI
import UIKit

enum MorpheTheme {
    // MORPHE brand palette — black + #FFD600 yellow.
    static let ink = Color(red: 0.043, green: 0.043, blue: 0.047)          // near-black base
    static let inkAlt = Color(red: 0.067, green: 0.067, blue: 0.067)       // #111111
    static let panel = Color(red: 0.118, green: 0.118, blue: 0.118).opacity(0.96)        // #1E1E1E
    static let panelStrong = Color(red: 0.150, green: 0.150, blue: 0.150).opacity(0.97)  // #262626
    static let panelRaised = Color(red: 0.173, green: 0.173, blue: 0.173).opacity(0.98)  // #2C2C2C
    static let panelInteractive = Color(red: 0.215, green: 0.215, blue: 0.215).opacity(0.98) // #373737
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.66)
    static let textMuted = Color.white.opacity(0.44)
    static let stroke = Color.white.opacity(0.10)
    static let strokeSubtle = Color.white.opacity(0.06)
    static let warning = Color(red: 0.98, green: 0.70, blue: 0.25)         // amber, distinct from accent
    static let danger = Color(red: 0.95, green: 0.36, blue: 0.36)
    static let lavender = Color(red: 0.72, green: 0.72, blue: 0.74)        // neutral (no off-brand purple)
    private static var currentAccentPalette: AccentPalette = .gold

    static var glow: Color {
        accent.opacity(0.22)
    }

    static var glowAlt: Color {
        accentAlt.opacity(0.18)
    }

    static var strokeStrong: Color {
        accent.opacity(0.34)
    }

    static var HUDGradient: LinearGradient {
        LinearGradient(
            colors: [panelRaised, panel],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
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
        ZStack {
            MorpheTheme.ink

            LinearGradient(
                colors: [
                    MorpheTheme.inkAlt.opacity(0.78),
                    MorpheTheme.ink.opacity(0.94),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            PerformanceGridOverlay()
                .opacity(0.55)

            RadialGradient(
                colors: [
                    MorpheTheme.accent.opacity(0.16),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 24,
                endRadius: 340
            )

            RadialGradient(
                colors: [
                    MorpheTheme.accentAlt.opacity(0.12),
                    .clear
                ],
                center: .bottomLeading,
                startRadius: 24,
                endRadius: 320
            )

            LinearGradient(
                colors: [
                    Color.white.opacity(0.03),
                    .clear,
                    Color.black.opacity(0.22)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [
                    Color.white.opacity(0.08),
                    .clear
                ],
                center: .topLeading,
                startRadius: 12,
                endRadius: 220
            )
            .blendMode(.screen)
        }
        .ignoresSafeArea()
    }
}

struct PrimaryCTAButtonStyle: ButtonStyle {
    var accent: Color = MorpheTheme.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(.black.opacity(0.92))
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                accent.opacity(configuration.isPressed ? 0.84 : 1),
                                MorpheTheme.accentAlt.opacity(configuration.isPressed ? 0.82 : 0.94)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )
            )
            .shadow(color: accent.opacity(0.26), radius: 16, x: 0, y: 10)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeInOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct SecondaryCTAButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(configuration.isPressed ? MorpheTheme.panelStrong : MorpheTheme.panel)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(MorpheTheme.strokeStrong.opacity(configuration.isPressed ? 0.8 : 0.45), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.18), radius: 12, x: 0, y: 8)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeInOut(duration: 0.16), value: configuration.isPressed)
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
