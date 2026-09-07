import ActivityKit
import SwiftUI
import WidgetKit

@main
struct MorpheWidgetsBundle: WidgetBundle {
    var body: some Widget {
        MorpheTodayWidget()
        WorkoutSessionLiveActivity()
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

    static func load(for renderDate: Date = .now) -> MorpheTodaySnapshot {
        let defaults = UserDefaults(suiteName: "group.com.morpheapp.Morphe")
        // "Logged today ✓" is only true on the DAY the app wrote it — a
        // snapshot from Monday must not brag on Tuesday's home screen.
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: renderDate)
        let renderDay = String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
        let snapshotDay = defaults?.string(forKey: "widget.day") ?? ""
        let isSameDay = snapshotDay == renderDay
        return MorpheTodaySnapshot(
            streak: defaults?.integer(forKey: "widget.streak") ?? 0,
            todayWorkout: defaults?.string(forKey: "widget.todayWorkout") ?? "",
            weekSets: defaults?.integer(forKey: "widget.weekSets") ?? 0,
            loggedToday: isSameDay && (defaults?.bool(forKey: "widget.loggedToday") ?? false),
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
        // The app reloads timelines on every state change; this policy only
        // bounds staleness in between. The midnight entry matters: it
        // re-renders with the new day so "Logged today ✓" flips off even if
        // the app never opens.
        let now = Date.now
        var entries = [MorpheTodayEntry(date: now, snapshot: .load(for: now))]
        if let midnight = Calendar.current.nextDate(
            after: now, matching: DateComponents(hour: 0, minute: 0, second: 5),
            matchingPolicy: .nextTime) {
            entries.append(MorpheTodayEntry(date: midnight, snapshot: .load(for: midnight)))
        }
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: now) ?? now
        completion(Timeline(entries: entries, policy: .after(next)))
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
                    .font(.system(.title3, design: .monospaced).weight(.bold))
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
                        .font(.system(.title3, design: .monospaced).weight(.bold))
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
// MARK: - Workout session Live Activity (Lucas 2026-08-30)
//
// The whole session on the lock screen: exercise + set progress always,
// Log Set / Rest / mic while working, the countdown (+15s / Skip) while
// resting. Buttons run LiveActivityIntents in the APP's process through
// the store's own doors; the mic opens the app straight into capture
// (iOS forbids third-party wake words on the lock screen).

private let morpheGold = Color(red: 1.0, green: 0.84, blue: 0.0)

struct WorkoutSessionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutSessionAttributes.self) { context in
            SessionLockScreenCard(context: context)
                .activityBackgroundTint(Color.black.opacity(0.85))
                .activitySystemActionForegroundColor(morpheGold)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.exerciseName)
                            .font(.subheadline.weight(.bold))
                            .lineLimit(1)
                        Text("SET \(min(context.state.setsDone + 1, context.state.setsTarget)) OF \(context.state.setsTarget)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let end = context.state.restEndDate {
                        Text(timerInterval: Date()...max(end, Date()), countsDown: true)
                            .font(.title3.weight(.bold)).monospacedDigit()
                            .foregroundStyle(morpheGold)
                            .frame(width: 64)
                    } else {
                        Image(systemName: "dumbbell.fill")
                            .foregroundStyle(morpheGold)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    SessionButtonsRow(context: context)
                }
            } compactLeading: {
                Image(systemName: "dumbbell.fill").foregroundStyle(morpheGold)
            } compactTrailing: {
                if let end = context.state.restEndDate {
                    Text(timerInterval: Date()...max(end, Date()), countsDown: true)
                        .monospacedDigit()
                        .foregroundStyle(morpheGold)
                        .frame(width: 44)
                } else {
                    Text("\(context.state.setsDone)/\(context.state.setsTarget)")
                        .foregroundStyle(morpheGold)
                }
            } minimal: {
                Image(systemName: "dumbbell.fill").foregroundStyle(morpheGold)
            }
        }
    }
}

private struct SessionLockScreenCard: View {
    let context: ActivityViewContext<WorkoutSessionAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.workoutName.uppercased())
                        .font(.caption2.weight(.semibold))
                        .tracking(1.1)
                        .foregroundStyle(.secondary)
                    Text(context.state.exerciseName)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if context.state.restEndDate == nil {
                    Text(context.state.workoutComplete
                         ? "DONE"
                         : "SET \(min(context.state.setsDone + 1, context.state.setsTarget)) OF \(context.state.setsTarget)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(morpheGold)
                }
            }

            if let end = context.state.restEndDate {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("RESTING")
                            .font(.caption2.weight(.semibold))
                            .tracking(1.1)
                            .foregroundStyle(.secondary)
                        Text(timerInterval: Date()...max(end, Date()), countsDown: true)
                            .font(.system(size: 34, weight: .bold)).monospacedDigit()
                            .foregroundStyle(morpheGold)
                    }
                    Spacer(minLength: 0)
                    Button(intent: AddRestTimeIntent()) {
                        Text("+15s").font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.bordered).tint(morpheGold)
                    Button(intent: SkipRestIntent()) {
                        Text("Skip").font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.bordered).tint(.secondary)
                }
            } else {
                SessionButtonsRow(context: context)
            }
        }
        .padding(14)
    }
}

/// Log the suggested set / start the rest / talk — shared by the lock
/// screen and the expanded island.
private struct SessionButtonsRow: View {
    let context: ActivityViewContext<WorkoutSessionAttributes>

    private var logLabel: String {
        let weight = context.state.suggestedWeight
        guard weight > 0 else { return "Log \(context.state.suggestedReps) reps" }
        let rounded = weight.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(weight)) : String(format: "%.1f", weight)
        return "Log \(context.state.suggestedReps) \u{00D7} \(rounded) \(context.state.unit)"
    }

    var body: some View {
        HStack(spacing: 10) {
            if context.state.workoutComplete {
                Text("Every set logged \u{2014} finish in the app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Button(intent: LogSetIntent()) {
                    Text(logLabel)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .buttonStyle(.borderedProminent)
                .tint(morpheGold)
                .foregroundStyle(.black)

                Button(intent: StartRestIntent()) {
                    Text("Rest").font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .tint(morpheGold)
            }
            Spacer(minLength: 0)
            Button(intent: SessionMicIntent()) {
                Image(systemName: "mic.fill")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .tint(morpheGold)
            .accessibilityLabel("Talk to Morphe")
        }
    }
}

