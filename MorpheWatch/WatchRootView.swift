import SwiftUI

/// Three states, one screen each: idle (start), lifting (log), resting
/// (countdown). Gold-on-ink to match the phone's brand.
struct WatchRootView: View {
    @EnvironmentObject private var model: WatchSessionModel

    private let gold = Color(red: 0.94, green: 0.78, blue: 0.28)

    var body: some View {
        Group {
            if model.restEndDate != nil {
                restView
            } else if model.sessionActive {
                sessionView
            } else {
                idleView
            }
        }
    }

    // MARK: Idle

    private var idleView: some View {
        VStack(spacing: 10) {
            Text(model.workoutName.isEmpty ? "Morphe" : model.workoutName)
                .font(.headline)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            if let notice = model.notice {
                Text(notice)
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            }
            if model.isReachable {
                Button {
                    model.startWorkout()
                } label: {
                    Label("Start", systemImage: "play.fill")
                        .font(.headline)
                }
                .tint(gold)
                Text("TRAIN HONEST")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(.secondary)
            } else {
                Text("Open Morphe on your iPhone to link up.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: Live session

    private var sessionView: some View {
        ScrollView {
            VStack(spacing: 8) {
                if model.workoutComplete {
                    Label("All sets logged", systemImage: "checkmark.seal.fill")
                        .font(.headline)
                        .foregroundStyle(gold)
                    Text("Finish and log on your iPhone — the recap and PRs live there.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text(model.exerciseName)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    Text("SET \(min(model.setsDone + 1, max(model.setsTarget, 1))) OF \(max(model.setsTarget, 1))")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.2)
                        .foregroundStyle(.secondary)
                    if let last = model.lastLine {
                        Text(last)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    adjusterRow(
                        label: "REPS",
                        value: "\(model.reps)",
                        down: { model.reps = max(1, model.reps - 1) },
                        up: { model.reps = min(50, model.reps + 1) }
                    )
                    adjusterRow(
                        label: "WEIGHT",
                        value: model.weightLabel,
                        down: { model.weight = max(0, model.weight - model.weightStep) },
                        up: { model.weight += model.weightStep }
                    )

                    Button {
                        model.logSet()
                    } label: {
                        Text(model.sending ? "…" : "LOG SET")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .tint(gold)
                    .disabled(model.sending || !model.isReachable)

                    HStack {
                        Button {
                            model.previous()
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                        .disabled(!model.canPrev)
                        Spacer()
                        Text("\(model.exerciseIndex + 1)/\(max(model.totalExercises, 1))")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            model.next()
                        } label: {
                            Image(systemName: "chevron.right")
                        }
                    }
                    .buttonStyle(.borderless)

                    if let notice = model.notice {
                        Text(notice)
                            .font(.system(size: 10))
                            .foregroundStyle(.orange)
                            .multilineTextAlignment(.center)
                    }
                    if !model.isReachable {
                        Text("iPhone unreachable — logging paused.")
                            .font(.system(size: 10))
                            .foregroundStyle(.orange)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func adjusterRow(label: String, value: String,
                             down: @escaping () -> Void,
                             up: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            Button(action: down) { Image(systemName: "minus") }
                .buttonStyle(.bordered)
                .controlSize(.small)
            VStack(spacing: 0) {
                Text(label)
                    .font(.system(size: 8, weight: .semibold))
                    .tracking(1.0)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(.body, design: .rounded).weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity)
            Button(action: up) { Image(systemName: "plus") }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
    }

    // MARK: Rest

    private var restView: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, Int((model.restEndDate?.timeIntervalSince(context.date) ?? 0).rounded()))
            let total = max(model.restSeconds, 1)
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(.tertiary, lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: CGFloat(remaining) / CGFloat(total))
                        .stroke(gold, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("\(remaining / 60):\(String(format: "%02d", remaining % 60))")
                            .font(.system(.title2, design: .rounded).weight(.bold))
                        Text("REST")
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(1.5)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 90, height: 90)
                Button("Skip") { model.skipRest() }
                    .controlSize(.small)
            }
        }
    }
}
