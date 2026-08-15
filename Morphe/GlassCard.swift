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

private struct PerformancePanelBackground: View {
    var cornerRadius: CGFloat = MorpheTheme.radius

    var body: some View {
        // Flat telemetry panel: one surface tint, one hairline, corner ticks.
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(MorpheTheme.panel)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(MorpheTheme.panelStrong, lineWidth: 1)
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
    /// Page-level headers directly under the floating profile icon drop the
    /// leading tick (it read as a stray arrow there); section headers deeper
    /// in a page keep it.
    var showsIndexTick: Bool = true

    var body: some View {
        // HUD header: accent index tick, tracked mono title, hairline rule
        // running to the trailing edge.
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                if showsIndexTick {
                    Rectangle()
                        .fill(MorpheTheme.accent)
                        .frame(width: 3, height: 14)
                }

                Text(title.uppercased())
                    // microLabel scales with Dynamic Type; the .bold keeps
                    // the section weight the fixed 14pt version had.
                    .font(MorpheTheme.microLabel(14).weight(.bold))
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

struct CelebrationOverlay: View {
    let moment: CelebrationMoment

    var body: some View {
        // Floats over scroll content like the toast, so it gets the same
        // treatment: solid ink fill + gold hairline. The translucent surface
        // tint read as see-through here.
        HStack(spacing: 12) {
            Image(systemName: moment.symbol)
                .font(.title3.weight(.bold))
                .foregroundStyle(MorpheTheme.accentText)

            VStack(alignment: .leading, spacing: 4) {
                Text(moment.title)
                    .font(.headline)
                    .foregroundStyle(MorpheTheme.textPrimary)
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
                    .foregroundStyle(MorpheTheme.brandYellowText)
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
                    .foregroundStyle(MorpheTheme.brandYellowText)

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
                        .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.brandYellow))
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
            Haptics.impact(.heavy)
            SoundEffects.play(.star)
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

            VStack(spacing: 2) {
                Text("\(score)")
                    .font(.system(.title2, design: .monospaced).weight(.bold))
                    .foregroundStyle(MorpheTheme.textPrimary)
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
                    .foregroundStyle(task.isCompleted ? MorpheTheme.accent : MorpheTheme.textMuted)
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
    let selected: WorkoutFeedbackOption?
    let response: String
    let onSelect: (WorkoutFeedbackOption) -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("How did this session feel?")
                    .font(.headline)
                    .foregroundStyle(MorpheTheme.textPrimary)

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
                    Text("Streak \(progress.streak) days")
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
                    .foregroundStyle(selectedRole == role ? .black : MorpheTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                            .fill(selectedRole == role ? MorpheTheme.accent : MorpheTheme.panelStrong)
                            .overlay(
                                RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                                    .stroke(selectedRole == role ? MorpheTheme.stroke : MorpheTheme.strokeStrong.opacity(0.20), lineWidth: 1)
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
                        // Named, not icons-only: six abstract glyphs made
                        // new users guess what Discover/Network/Learn were
                        // (audit BLOCKER). Mono micro-labels keep the HUD.
                        Text(item.title.uppercased())
                            .font(MorpheTheme.microLabel(8))
                            .tracking(0.8)
                            .lineLimit(1)
                        Circle()
                            .fill(selected == item ? MorpheTheme.accent : .clear)
                            .frame(width: 4, height: 4)
                    }
                    .foregroundStyle(selected == item ? MorpheTheme.accent : MorpheTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(item.title))
                .accessibilityAddTraits(selected == item ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(.horizontal, 6)
        // Bottom keeps its ink strip + hairline (per Lucas's on-device
        // read: dock stays solid; only the TOP is chrome-free icons).
        .background(
            MorpheTheme.ink.opacity(0.94)
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(MorpheTheme.stroke)
                .frame(height: 1)
        }
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
                                .foregroundStyle(MorpheTheme.accentText)
                            Text(badge.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(MorpheTheme.textPrimary)
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

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isSelected ? .black : MorpheTheme.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: MorpheTheme.chipRadius, style: .continuous)
                    .fill(isSelected ? selectedColor : (configuration.isPressed ? MorpheTheme.panelStrong : MorpheTheme.panel))
            )
            .overlay(
                RoundedRectangle(cornerRadius: MorpheTheme.chipRadius, style: .continuous)
                    .stroke(isSelected ? Color.clear : MorpheTheme.stroke, lineWidth: 1)
            )
            // Selection was color-only — invisible to VoiceOver and weak for
            // color-blind users. Every chip in the app gets the trait from here.
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            // The most common tap in the app gets the standard selection
            // tick — fired on press-down so it lands with the touch.
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { Haptics.selection() }
            }
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

// MARK: - Fetch states (shared by every fetched surface)

/// Placeholder while a FIRST fetch answers — empty copy before the
/// network has spoken is a lie.
struct FetchPlaceholderCard: View {
    let line: String

    var body: some View {
        GlassCard {
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
        GlassCard {
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
        GlassCard {
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
                Text("TRAIN HONEST")
                    .scaledFont(size: 13, weight: .bold, design: .monospaced)
                    .tracking(2.4)
                    .foregroundStyle(MorpheTheme.brandYellow)
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
                    Text("MORPHE")
                        .font(.system(size: 22, design: .monospaced).weight(.black))
                        .tracking(6)
                        .foregroundStyle(MorpheTheme.brandYellow)
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
                    Text("TRAIN HONEST")
                        .font(.system(size: 12, design: .monospaced).weight(.bold))
                        .tracking(1.6)
                        .foregroundStyle(MorpheTheme.brandYellow)
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
        if data.setCount > 0 { facts.append("\(data.setCount) SETS") }
        if data.exerciseCount > 0 { facts.append("\(data.exerciseCount) MOVES") }
        if data.minutes > 0 { facts.append("\(data.minutes) MIN") }
        return facts.joined(separator: "   ·   ")
    }

    var body: some View {
        ShareCardFrame(dateLabel: data.dateLabel, username: data.username) {
            VStack(alignment: .leading, spacing: 0) {
                ShareCardKicker(text: "SESSION COMPLETE")
                    .padding(.bottom, 10)

                Text(data.workoutName)
                    .font(.system(size: 40, weight: .black))
                    .foregroundStyle(MorpheTheme.textPrimary)
                    .lineLimit(3)
                    .minimumScaleFactor(0.6)
                    .padding(.bottom, 18)

                if !factLine.isEmpty {
                    Text(factLine)
                        .font(.system(size: 15, design: .monospaced).weight(.bold))
                        .tracking(1.2)
                        .foregroundStyle(MorpheTheme.brandYellow)
                        .padding(.bottom, 18)
                }

                ForEach(data.prNames, id: \.self) { name in
                    HStack(spacing: 8) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(MorpheTheme.brandYellow)
                        Text("NEW PR · \(name.uppercased())")
                            .font(.system(size: 13, design: .monospaced).weight(.bold))
                            .tracking(1.2)
                            .foregroundStyle(MorpheTheme.textPrimary)
                            .lineLimit(1)
                    }
                    .padding(.bottom, 8)
                }

                if data.streak >= 2 {
                    HStack(spacing: 8) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(MorpheTheme.brandYellow)
                        Text("\(data.streak)-DAY STREAK")
                            .font(.system(size: 13, design: .monospaced).weight(.bold))
                            .tracking(1.2)
                            .foregroundStyle(MorpheTheme.textPrimary)
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
                        .foregroundStyle(MorpheTheme.brandYellow)
                    ShareCardKicker(text: "NEW RECORD")
                }
                .padding(.bottom, 10)

                Text(data.exerciseName)
                    .font(.system(size: 40, weight: .black))
                    .foregroundStyle(MorpheTheme.textPrimary)
                    .lineLimit(3)
                    .minimumScaleFactor(0.6)
                    .padding(.bottom, 18)

                Text(data.weightLabel.uppercased())
                    .font(.system(size: 34, design: .monospaced).weight(.bold))
                    .foregroundStyle(MorpheTheme.brandYellow)

                if !data.previousLabel.isEmpty {
                    Text("UP FROM \(data.previousLabel.uppercased())")
                        .font(.system(size: 13, design: .monospaced).weight(.semibold))
                        .tracking(1.2)
                        .foregroundStyle(MorpheTheme.textPrimary.opacity(0.55))
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
                        .foregroundStyle(MorpheTheme.brandYellow)
                    ShareCardKicker(text: "CONSISTENCY")
                }
                .padding(.bottom, 14)

                Text("\(data.streak)")
                    .font(.system(size: 96, design: .monospaced).weight(.bold))
                    .foregroundStyle(MorpheTheme.brandYellow)

                Text("DAY STREAK")
                    .font(.system(size: 18, design: .monospaced).weight(.bold))
                    .tracking(3)
                    .foregroundStyle(MorpheTheme.textPrimary)
                    .padding(.bottom, 14)

                Text("EVERY DAY EARNED")
                    .font(.system(size: 12, design: .monospaced).weight(.semibold))
                    .tracking(1.6)
                    .foregroundStyle(MorpheTheme.textPrimary.opacity(0.55))
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
                    .foregroundStyle(MorpheTheme.brandYellow)

                Text(data.sessions == 1 ? "SESSION" : "SESSIONS")
                    .font(.system(size: 18, design: .monospaced).weight(.bold))
                    .tracking(3)
                    .foregroundStyle(MorpheTheme.textPrimary)
                    .padding(.bottom, 16)

                Text("\(data.sets) SETS   ·   \(data.minutes) MIN")
                    .font(.system(size: 15, design: .monospaced).weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(MorpheTheme.textPrimary)

                if data.prCount > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(MorpheTheme.brandYellow)
                        Text("\(data.prCount) NEW PR\(data.prCount == 1 ? "" : "S")")
                            .font(.system(size: 13, design: .monospaced).weight(.bold))
                            .tracking(1.2)
                            .foregroundStyle(MorpheTheme.textPrimary)
                    }
                    .padding(.top, 12)
                }

                if data.streak >= 2 {
                    HStack(spacing: 8) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(MorpheTheme.brandYellow)
                        Text("\(data.streak)-DAY STREAK")
                            .font(.system(size: 13, design: .monospaced).weight(.bold))
                            .tracking(1.2)
                            .foregroundStyle(MorpheTheme.textPrimary)
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
