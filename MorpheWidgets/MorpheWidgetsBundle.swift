import ActivityKit
import SwiftUI
import WidgetKit

@main
struct MorpheWidgetsBundle: WidgetBundle {
    var body: some Widget {
        MorpheTodayWidget()
        RestTimerLiveActivity()
    }
}

// MARK: - Today widget (home screen + lock screen)
//
// Reads the four-primitive snapshot the app writes to the shared app-group
// defaults on every launch/log. Honest by construction: it renders exactly
// what the app last knew — streak, today's workout, sets this week — and a
// fresh install with no data says so instead of faking zeros as progress.

private struct MorpheTodaySnapshot {
    var streak: Int
    var todayWorkout: String
    var weekSets: Int
    var loggedToday: Bool
    var hasData: Bool

    static func load() -> MorpheTodaySnapshot {
        let defaults = UserDefaults(suiteName: "group.com.morpheapp.Morphe")
        return MorpheTodaySnapshot(
            streak: defaults?.integer(forKey: "widget.streak") ?? 0,
            todayWorkout: defaults?.string(forKey: "widget.todayWorkout") ?? "",
            weekSets: defaults?.integer(forKey: "widget.weekSets") ?? 0,
            loggedToday: defaults?.bool(forKey: "widget.loggedToday") ?? false,
            hasData: defaults?.object(forKey: "widget.todayWorkout") != nil
        )
    }
}

private struct MorpheTodayEntry: TimelineEntry {
    let date: Date
    let snapshot: MorpheTodaySnapshot
}

private struct MorpheTodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> MorpheTodayEntry {
        MorpheTodayEntry(date: .now, snapshot: MorpheTodaySnapshot(
            streak: 5, todayWorkout: "Push Day", weekSets: 24, loggedToday: false, hasData: true))
    }

    func getSnapshot(in context: Context, completion: @escaping (MorpheTodayEntry) -> Void) {
        completion(MorpheTodayEntry(date: .now, snapshot: .load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MorpheTodayEntry>) -> Void) {
        // The app reloads timelines on every state change; the hourly
        // refresh only keeps relative staleness bounded overnight.
        let entry = MorpheTodayEntry(date: .now, snapshot: .load())
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct MorpheTodayWidget: Widget {
    private static let gold = Color(red: 1.0, green: 0.84, blue: 0.0)

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MorpheTodayWidget", provider: MorpheTodayProvider()) { entry in
            MorpheTodayWidgetView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) {
                    Color(red: 0.02, green: 0.02, blue: 0.024)
                }
        }
        .configurationDisplayName("Today's Training")
        .description("Your streak, today's workout, and this week's sets.")
        .supportedFamilies([.systemSmall, .accessoryRectangular, .accessoryCircular])
    }
}

private struct MorpheTodayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: MorpheTodaySnapshot

    private static let gold = Color(red: 1.0, green: 0.84, blue: 0.0)

    var body: some View {
        switch family {
        case .accessoryCircular:
            // Streak dial for the lock screen.
            VStack(spacing: 0) {
                Image(systemName: "flame.fill")
                    .font(.caption2)
                Text("\(snapshot.streak)")
                    .font(.system(.title3, design: .rounded).weight(.bold))
            }
            .accessibilityLabel("\(snapshot.streak) day streak")
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.caption2)
                    Text("\(snapshot.streak)-day streak")
                        .font(.caption.weight(.semibold))
                }
                Text(snapshot.loggedToday ? "Logged today" : snapshot.todayWorkout)
                    .font(.caption2)
                    .lineLimit(1)
                Text("\(snapshot.weekSets) sets this week")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        default:
            // Home-screen small: today's decision at a glance.
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.caption)
                        .foregroundStyle(Self.gold)
                    Text("\(snapshot.streak)")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)
                    Text("DAY STREAK")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(1.1)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                if snapshot.hasData {
                    Text(snapshot.loggedToday ? "In the books" : "Up today")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(1.1)
                        .foregroundStyle(Self.gold)
                    Text(snapshot.loggedToday ? "Workout logged ✓" : snapshot.todayWorkout)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text("\(snapshot.weekSets) sets this week")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Open Morphe to start — the widget fills in from your first session.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
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
