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
    var weekBars: [Int]

    static func load(for renderDate: Date = .now) -> MorpheTodaySnapshot {
        let defaults = UserDefaults(suiteName: "group.com.morpheapp.Morphe")
        // "Logged today ✓" is only true on the DAY the app wrote it — a
        // snapshot from Monday must not brag on Tuesday's home screen.
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: renderDate)
        let renderDay = String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
        let snapshotDay = defaults?.string(forKey: "widget.day") ?? ""
        let isSameDay = snapshotDay == renderDay
        // Bars are "7 days ending on the day the app WROTE them" — after
        // midnight with the app unopened, the gold rightmost bar would be
        // yesterday's (audit 26, P2: the widget contradicted its own "UP
        // TODAY"). Shift left by the days elapsed since the snapshot.
        var bars = (defaults?.array(forKey: "widget.weekBars") as? [Int]) ?? []
        if bars.count == 7, !snapshotDay.isEmpty, snapshotDay != renderDay,
           let written = Self.day(from: snapshotDay),
           let rendered = Self.day(from: renderDay) {
            let elapsed = Calendar.current.dateComponents([.day], from: written, to: rendered).day ?? 0
            if elapsed > 0 {
                let shift = min(elapsed, 7)
                bars = Array(bars.dropFirst(shift)) + Array(repeating: 0, count: shift)
            }
        }
        // A streak claim is only true through its allowed rest gap — the
        // app writes the horizon; past it, the widget stops bragging
        // (audit 26, P2). yyyy-mm-dd compares correctly as a string.
        var streak = defaults?.integer(forKey: "widget.streak") ?? 0
        if let validThrough = defaults?.string(forKey: "widget.streakValidThrough"),
           renderDay > validThrough {
            streak = 0
        }
        return MorpheTodaySnapshot(
            streak: streak,
            todayWorkout: defaults?.string(forKey: "widget.todayWorkout") ?? "",
            weekSets: defaults?.integer(forKey: "widget.weekSets") ?? 0,
            loggedToday: isSameDay && (defaults?.bool(forKey: "widget.loggedToday") ?? false),
            hasData: defaults?.bool(forKey: "widget.hasLogs") ?? false,
            weekBars: bars
        )
    }

    private static func day(from key: String) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}

private struct MorpheTodayEntry: TimelineEntry {
    let date: Date
    let snapshot: MorpheTodaySnapshot
}

private struct MorpheTodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> MorpheTodayEntry {
        MorpheTodayEntry(date: .now, snapshot: MorpheTodaySnapshot(
            streak: 5, todayWorkout: "Push Day", weekSets: 24, loggedToday: false, hasData: true,
            weekBars: [6, 0, 4, 5, 0, 5, 4]))
    }

    func getSnapshot(in context: Context, completion: @escaping (MorpheTodayEntry) -> Void) {
        let snapshot = MorpheTodaySnapshot.load()
        // The widget GALLERY on a fresh install shows the sample, not a
        // wall of zeros (audit 26) — real data still previews as itself.
        if context.isPreview, !snapshot.hasData {
            completion(placeholder(in: context))
        } else {
            completion(MorpheTodayEntry(date: .now, snapshot: snapshot))
        }
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
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MorpheTodayWidget", provider: MorpheTodayProvider()) { entry in
            MorpheTodayWidgetView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) {
                    // Matches MorpheTheme.ink dark (design wave 2026-10-01).
                    Color(red: 0.071, green: 0.071, blue: 0.078)
                }
        }
        .configurationDisplayName("Today's Training")
        .description("Your streak, today's workout, and this week's sets.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular])
    }
}

private struct MorpheTodayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: MorpheTodaySnapshot

    private static let gold = Color(red: 0.478, green: 0.635, blue: 1.0)  // spartan blue on dark (rebrand 2026-10-01)

    var body: some View {
        switch family {
        case .accessoryCircular:
            // Streak dial for the lock screen — a fresh install says so
            // instead of faking a zero streak (audit 26, P2).
            if snapshot.hasData {
                VStack(spacing: 0) {
                    Image(systemName: "flame.fill")
                        .font(.caption2)
                        .widgetAccentable()
                    Text("\(snapshot.streak)")
                        .font(.system(.title3, design: .monospaced).weight(.bold))
                }
                .accessibilityLabel("\(snapshot.streak) day streak")
            } else {
                Image(systemName: "dumbbell.fill")
                    .font(.title3)
                    .accessibilityLabel("Open Morphe to start")
            }
        case .accessoryRectangular:
            if snapshot.hasData {
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.caption2)
                            .widgetAccentable()
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
            } else {
                Text("Open Morphe to start — this fills in from your first session.")
                    .font(.caption2)
            }
        case .systemMedium:
            // Home-screen medium: today's decision PLUS the week's shape —
            // seven bars of real logged sets, today on the right.
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.caption)
                            .foregroundStyle(Self.gold)
                            .widgetAccentable()
                        Text("\(snapshot.streak)")
                            .font(.system(.title3, design: .monospaced).weight(.bold))
                            .foregroundStyle(.white)
                            .minimumScaleFactor(0.7)
                        Text("DAY STREAK")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .tracking(1.1)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    if snapshot.hasData {
                        Text(snapshot.loggedToday ? "IN THE BOOKS" : "UP TODAY")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .tracking(1.1)
                            .foregroundStyle(Self.gold)
                            .widgetAccentable()
                        Text(snapshot.loggedToday ? "Workout logged \u{2713}" : snapshot.todayWorkout)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                    } else {
                        Text("Open Morphe to start \u{2014} the widget fills in from your first session.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if snapshot.hasData {
                    VStack(alignment: .trailing, spacing: 6) {
                        Text("LAST 7 DAYS")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .tracking(1.1)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        WeekBarsRow(bars: snapshot.weekBars)
                        // The total is the bars' own sum (audit 26, P1:
                        // "this week" was a CALENDAR week — a different
                        // window than the rolling bars above it, so the
                        // two numbers could contradict each other).
                        Text("\(snapshot.weekBars.reduce(0, +)) sets · last 7 days")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        default:
            // Home-screen small: today's decision at a glance.
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.caption)
                        .foregroundStyle(Self.gold)
                        .widgetAccentable()
                    Text("\(snapshot.streak)")
                        .font(.system(.title3, design: .monospaced).weight(.bold))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.7)
                    Text("DAY STREAK")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(1.1)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if snapshot.hasData {
                    Text(snapshot.loggedToday ? "In the books" : "Up today")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(1.1)
                        .foregroundStyle(Self.gold)
                        .widgetAccentable()
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
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

/// Seven days of real logged sets as capsules, today rightmost. Bars
/// scale to the week's own max; an empty day stays a visible stub so the
/// row never lies by omission.
private struct WeekBarsRow: View {
    let bars: [Int]

    private static let gold = Color(red: 0.478, green: 0.635, blue: 1.0)  // spartan blue on dark (rebrand 2026-10-01)

    var body: some View {
        let shown = bars.count == 7 ? bars : Array(repeating: 0, count: 7)
        let top = max(shown.max() ?? 1, 1)
        HStack(alignment: .bottom, spacing: 5) {
            ForEach(Array(shown.enumerated()), id: \.offset) { index, sets in
                Capsule(style: .continuous)
                    .fill(sets > 0 ? Self.gold.opacity(index == 6 ? 1 : 0.75)
                                   : Color.white.opacity(0.14))
                    .widgetAccentable(sets > 0)
                    .frame(width: 9, height: sets > 0 ? max(10, 42 * CGFloat(sets) / CGFloat(top)) : 4)
            }
        }
        .frame(height: 44, alignment: .bottom)
        .accessibilityLabel("Sets over the last seven days: \(shown.map(String.init).joined(separator: ", "))")
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

private let morpheGold = Color(red: 0.478, green: 0.635, blue: 1.0)  // spartan blue on dark (rebrand 2026-10-01)

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
                } else if context.state.workoutComplete {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(morpheGold)
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

