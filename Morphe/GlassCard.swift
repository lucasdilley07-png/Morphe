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

struct CoachLayout<Content: View>: View {
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
private struct HUDCornerTicks: View {
    var arm: CGFloat = 9
    var color: Color = Color.white.opacity(0.22)

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

private struct PerformancePanelBackground: View {
    var cornerRadius: CGFloat = MorpheTheme.radius

    var body: some View {
        // Flat telemetry panel: one surface tint, one hairline, corner ticks.
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(MorpheTheme.panel)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .overlay(HUDCornerTicks())
    }
}

struct GlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(PerformancePanelBackground())
    }
}

struct SectionTitleView: View {
    let title: String
    let subtitle: String

    var body: some View {
        // HUD header: accent index tick, tracked mono title, hairline rule
        // running to the trailing edge.
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Rectangle()
                    .fill(MorpheTheme.accent)
                    .frame(width: 3, height: 14)

                Text(title.uppercased())
                    .font(.system(size: 14, design: .monospaced).weight(.bold))
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 6)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
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
                    .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                    .foregroundStyle(MorpheTheme.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
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
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 2, style: .continuous)
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
                    .fill(Color.white.opacity(0.08))

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
            .foregroundStyle(.white)
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

struct CelebrationOverlay: View {
    let moment: CelebrationMoment

    var body: some View {
        // Floats over scroll content like the toast, so it gets the same
        // treatment: solid ink fill + gold hairline. The translucent surface
        // tint read as see-through here.
        HStack(spacing: 12) {
            Image(systemName: moment.symbol)
                .font(.title3.weight(.bold))
                .foregroundStyle(MorpheTheme.accent)

            VStack(alignment: .leading, spacing: 4) {
                Text(moment.title)
                    .font(.headline)
                    .foregroundStyle(.white)
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
    }
}

struct MorpheAvatarView: View {
    let avatar: AvatarProfile
    let size: CGFloat

    init(avatar: AvatarProfile, size: CGFloat = 64) {
        self.avatar = avatar
        self.size = size
    }

    var body: some View {
        // HUD identity tile: flat square, hairline, yellow glyph — the old
        // gold-coin gradient was the last piece of glass in the header.
        ZStack {
            RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                .fill(MorpheTheme.panelStrong)
                .overlay(
                    RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )

            Image(systemName: avatar.style.systemImage)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(MorpheTheme.accent)
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

    private var iconAccent: LinearGradient {
        switch avatar.style {
        case .cleanStarter:
            return LinearGradient(colors: [Color.white.opacity(0.95), MorpheTheme.accentAlt.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .fightReady:
            return LinearGradient(colors: [Color(red: 0.98, green: 0.50, blue: 0.40), Color(red: 0.95, green: 0.26, blue: 0.30)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .matchFit:
            return LinearGradient(colors: [Color(red: 0.54, green: 0.95, blue: 0.66), Color(red: 0.17, green: 0.72, blue: 0.41)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .jumpDay:
            return LinearGradient(colors: [Color(red: 1.00, green: 0.78, blue: 0.46), Color(red: 0.97, green: 0.46, blue: 0.14)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .roadRunner:
            return LinearGradient(colors: [Color(red: 0.70, green: 0.93, blue: 1.0), MorpheTheme.accent], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .strengthBuilder:
            return LinearGradient(colors: [MorpheTheme.lavender, Color(red: 0.58, green: 0.42, blue: 0.92)], startPoint: .topLeading, endPoint: .bottomTrailing)
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
                        .foregroundStyle(Color.white.opacity(0.12))
                        .padding(18)
                }
                .overlay(alignment: .topLeading) {
                    VStack(spacing: 7) {
                        ForEach(0..<8, id: \.self) { _ in
                            Capsule(style: .continuous)
                                .fill(Color.white.opacity(0.06))
                                .frame(width: 58, height: 1)
                        }
                    }
                    .padding(18)
                }


            VStack(alignment: .leading, spacing: 10) {
                Text(eyebrowText(for: banner.preset))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.white.opacity(0.82))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .stroke(Color.white.opacity(0.25), lineWidth: 1)
                    )

                Text(banner.title)
                    .font(.title.weight(.bold))
                    .foregroundStyle(.white)

                Text(banner.subtitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.84))
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity, minHeight: 148)
    }

    private func gradientColors(for theme: ThemePreset) -> [Color] {
        switch theme {
        case .boxingRedCharcoal:
            return [Color(red: 0.88, green: 0.30, blue: 0.24), Color.black.opacity(0.9)]
        case .soccerGreenWhite:
            return [Color(red: 0.18, green: 0.70, blue: 0.40), Color.white.opacity(0.18)]
        case .basketballOrangeBlack:
            return [Color(red: 0.95, green: 0.48, blue: 0.18), Color.black.opacity(0.92)]
        case .recoveryBlueGray:
            return [Color(red: 0.32, green: 0.62, blue: 0.94), Color(red: 0.42, green: 0.46, blue: 0.54)]
        case .strengthPurpleGraphite:
            return [MorpheTheme.lavender, Color(red: 0.18, green: 0.20, blue: 0.24)]
        case .minimalWhiteBlack:
            return [Color.white.opacity(0.20), Color.black.opacity(0.92)]
        case .goldPremium:
            return [Color(red: 0.92, green: 0.80, blue: 0.42), Color(red: 0.26, green: 0.22, blue: 0.12)]
        default:
            return [MorpheTheme.accentAlt, Color.black.opacity(0.88)]
        }
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
                    .foregroundStyle(.white)

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
                        .foregroundStyle(.white)
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

struct EmptyStateCard: View {
    let title: String
    let detail: String

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(detail)
                    .foregroundStyle(MorpheTheme.textSecondary)
            }
        }
    }
}

struct ScoreRing: View {
    let score: Int
    let color: Color

    var body: some View {
        // Thin instrument ring: flat color, square cap, mono numerals.
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 4)

            Circle()
                .trim(from: 0, to: Double(score) / 100.0)
                .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .butt))
                .rotationEffect(.degrees(-90))

            VStack(spacing: 2) {
                Text("\(score)")
                    .font(.system(.title2, design: .monospaced).weight(.bold))
                    .foregroundStyle(.white)
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
                            .foregroundStyle(.white)
                        Text(health.headline)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
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
                        .foregroundStyle(.white)

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
                    .foregroundStyle(MorpheTheme.accent)
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
                            .foregroundStyle(.white)
                        Text(recovery.status.rawValue)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
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

struct ConfidenceRatingCard: View {
    let selected: ConfidenceLevel?
    let onSelect: (ConfidenceLevel) -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("How confident are you that you can complete this today?")
                    .font(.headline)
                    .foregroundStyle(.white)

                HStack(spacing: 8) {
                    ForEach(ConfidenceLevel.allCases) { level in
                        Button(level.rawValue) {
                            onSelect(level)
                        }
                        .buttonStyle(FilterChipStyle(isSelected: selected == level, selectedColor: MorpheTheme.accent))
                    }
                }

                if selected == .notConfident {
                    Text("Let's make this easier today.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MorpheTheme.warning)
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
                    .foregroundStyle(.white)

                Text(adjustment.body)
                    .foregroundStyle(MorpheTheme.textPrimary)

                WrapStack(spacing: 8) {
                    ForEach(adjustment.reasons) { reason in
                        Text(reason.rawValue)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
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
                    .foregroundStyle(.white)
                Text(translation.goal)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)

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
                    .foregroundStyle(.white)
                Text("Morphe uses these rules to adjust your plan.")
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)

                ForEach(rules) { rule in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(rule.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
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
                    .foregroundStyle(.white)
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MorpheTheme.accent)
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
                    .foregroundStyle(task.isCompleted ? MorpheTheme.accent : MorpheTheme.textMuted)
                    .font(.headline)

                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
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

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Minimum Win Mode")
                    .font(.headline)
                    .foregroundStyle(.white)
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
                    .foregroundStyle(.white)

                if isProtected {
                    Text("Momentum protected.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MorpheTheme.accent)
                } else {
                    Text("You missed today's workout, but your streak is still saveable.")
                        .foregroundStyle(MorpheTheme.textSecondary)

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
                            .foregroundStyle(.white)
                        Text(workout.name)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
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
    let selected: WorkoutFeedbackOption?
    let response: String
    let onSelect: (WorkoutFeedbackOption) -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("How did this session feel?")
                    .font(.headline)
                    .foregroundStyle(.white)

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
                        .foregroundStyle(MorpheTheme.accent)
                }
            }
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
                        .foregroundStyle(.white)
                    Spacer()
                    Button("Next", action: onNext)
                        .buttonStyle(SecondaryCTAButtonStyle())
                        .frame(width: 88)
                }

                Text(insight.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MorpheTheme.accent)

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
                    .foregroundStyle(.white)

                ForEach(phases) { phase in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            HStack(spacing: 8) {
                                Image(systemName: iconName(for: phase.status))
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(color(for: phase.status))
                                Text(phase.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
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
                    .foregroundStyle(.white)

                HStack(spacing: 8) {
                    PhotoSlotView(label: snapshot.frontLabel)
                    PhotoSlotView(label: snapshot.sideLabel)
                    PhotoSlotView(label: snapshot.backLabel)
                }

                Text(snapshot.reminder)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MorpheTheme.accent)
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
        .weightLoss,
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
                    .foregroundStyle(.white)
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
                        .foregroundStyle(.white)
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
                            .foregroundStyle(.white)
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
                    .foregroundStyle(.white)

                ForEach(Array(notifications.prefix(3))) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(item.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
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
                    .foregroundStyle(.white)

                Text(progress.currentTitle)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)

                ProgressBarView(progress: progress.progress, color: MorpheTheme.accent)

                HStack {
                    Text("XP \(progress.currentXP) / \(progress.targetXP)")
                        .foregroundStyle(MorpheTheme.textSecondary)
                    Spacer()
                    Text("Streak \(progress.streak) days")
                        .foregroundStyle(MorpheTheme.textSecondary)
                }
                .font(.subheadline)

                Text("Next Level: \(progress.nextTitle)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
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
                    .foregroundStyle(.white)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
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

struct RoleSwitcher: View {
    let selectedRole: AppRole
    let onSelect: (AppRole) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(AppRole.allCases) { role in
                Button {
                    onSelect(role)
                } label: {
                    VStack(spacing: 6) {
                        Text(role.title)
                            .font(.subheadline.weight(.semibold))
                        Text(role.subtitle)
                            .font(.caption2)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(selectedRole == role ? .black : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                            .fill(selectedRole == role ? MorpheTheme.accent : MorpheTheme.panelStrong)
                            .overlay(
                                RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                                    .stroke(selectedRole == role ? Color.white.opacity(0.18) : MorpheTheme.strokeStrong.opacity(0.20), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct BottomTabNavigation<Item: MorpheTabItem & CaseIterable>: View where Item.AllCases == [Item] {
    let items: [Item]
    let selected: Item
    let onSelect: (Item) -> Void

    var body: some View {
        MorpheTabBar(items: items, selected: selected, onSelect: onSelect)
    }
}

struct MorpheTabBar<Item: MorpheTabItem & CaseIterable>: View where Item.AllCases == [Item] {
    let items: [Item]
    let selected: Item
    let onSelect: (Item) -> Void

    var body: some View {
        // HUD dock: solid ink bar, hairline frame; the active tab is yellow
        // text over a thin underline tick — no filled pills.
        HStack(spacing: 4) {
            ForEach(items, id: \.self) { item in
                Button {
                    onSelect(item)
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: item.systemImage)
                            .font(.system(.subheadline).weight(.semibold))
                        Text(item.title.uppercased())
                            .font(MorpheTheme.microLabel(9))
                            .tracking(1.0)
                            .lineLimit(1)
                        Rectangle()
                            .fill(selected == item ? MorpheTheme.accent : .clear)
                            .frame(width: 26, height: 2)
                    }
                    .foregroundStyle(selected == item ? MorpheTheme.accent : Color.white.opacity(0.55))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
                    .padding(.bottom, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(item.title))
                .accessibilityAddTraits(selected == item ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                .fill(MorpheTheme.ink.opacity(0.97))
                .overlay(
                    RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
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
                            .foregroundStyle(.white)
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
                    .foregroundStyle(.white)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(badges) { badge in
                        VStack(alignment: .leading, spacing: 8) {
                            Image(systemName: badge.icon)
                                .foregroundStyle(MorpheTheme.accent)
                            Text(badge.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Text(badge.detail)
                                .font(.caption)
                                .foregroundStyle(MorpheTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                                .fill(MorpheTheme.panelStrong)
                        )
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
                            .foregroundStyle(.white)
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

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isSelected ? .black : .white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(isSelected ? selectedColor : (configuration.isPressed ? MorpheTheme.panelStrong : Color.white.opacity(0.04)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .stroke(isSelected ? Color.clear : Color.white.opacity(0.10), lineWidth: 1)
            )
            // Selection was color-only — invisible to VoiceOver and weak for
            // color-blind users. Every chip in the app gets the trait from here.
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct MorpheFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<_Label>) -> some View {
        configuration
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
            )
            .foregroundStyle(.white)
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
                        .foregroundStyle(.white)
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
                        .foregroundStyle(MorpheTheme.accent)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

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
