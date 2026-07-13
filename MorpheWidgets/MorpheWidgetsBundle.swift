import ActivityKit
import SwiftUI
import WidgetKit

@main
struct MorpheWidgetsBundle: WidgetBundle {
    var body: some Widget {
        RestTimerLiveActivity()
    }
}

/// Lock screen + Dynamic Island UI for the in-workout rest timer.
struct RestTimerLiveActivity: Widget {
    // MORPHE signature yellow + near-black ink (mirrors MorpheTheme, which
    // isn't compiled into the extension).
    private static let gold = Color(red: 1.0, green: 0.84, blue: 0.0)
    private static let ink = Color(red: 0.02, green: 0.02, blue: 0.024)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestTimerAttributes.self) { context in
            // Lock screen banner.
            HStack(spacing: 14) {
                Image(systemName: "timer")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Self.gold)

                VStack(alignment: .leading, spacing: 2) {
                    Text("REST")
                        .font(.caption2.weight(.bold))
                        .tracking(1.4)
                        .foregroundStyle(.secondary)
                    Text(context.attributes.exerciseName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }

                Spacer()

                Text(timerInterval: context.state.startDate...context.state.endDate, countsDown: true)
                    .font(.system(.title, design: .monospaced).weight(.bold))
                    .foregroundStyle(Self.gold)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 96)
            }
            .padding(16)
            .activityBackgroundTint(Self.ink.opacity(0.92))
            .activitySystemActionForegroundColor(Self.gold)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("Rest", systemImage: "timer")
                        .font(.headline)
                        .foregroundStyle(Self.gold)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: context.state.startDate...context.state.endDate, countsDown: true)
                        .monospacedDigit()
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Self.gold)
                        .frame(maxWidth: 80)
                        .multilineTextAlignment(.trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.attributes.exerciseName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundStyle(Self.gold)
            } compactTrailing: {
                Text(timerInterval: context.state.startDate...context.state.endDate, countsDown: true)
                    .monospacedDigit()
                    .foregroundStyle(Self.gold)
                    .frame(maxWidth: 48)
            } minimal: {
                Image(systemName: "timer")
                    .foregroundStyle(Self.gold)
            }
        }
    }
}
