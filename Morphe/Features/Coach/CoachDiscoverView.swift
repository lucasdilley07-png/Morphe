import SwiftUI

// MARK: - Coach Discover
//
// One place for the coach's content tools: browse and save catalog workouts,
// build their own, find athletes on their roster, and connect via QR code.

struct CoachDiscoverScreen: View {
    @Environment(MorpheAppStore.self) private var store

    @State private var athleteQuery = ""
    @State private var workoutQuery = ""
    @State private var showBuilder = false
    @State private var showQRConnect = false
    @State private var qrStartMode: QRConnectSheet.Mode = .show
    @State private var showSavedOnly = false

    private var athleteResults: [CoachClient] {
        let query = athleteQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        return store.coachClients.filter {
            $0.name.localizedCaseInsensitiveContains(query)
        }
    }

    private var workoutResults: [WorkoutTemplate] {
        let query = workoutQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let pool = showSavedOnly
            ? store.discoverWorkouts.filter { store.isCatalogWorkoutSaved($0) }
            : store.discoverWorkouts
        guard !query.isEmpty else { return Array(pool.prefix(12)) }
        return Array(
            pool.filter {
                $0.name.localizedCaseInsensitiveContains(query)
                    || $0.goal.localizedCaseInsensitiveContains(query)
                    || $0.trainingTypeTag.localizedCaseInsensitiveContains(query)
            }
            .prefix(30)
        )
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                SectionTitleView(
                    title: "Discover",
                    subtitle: "Find workouts for your athletes, build your own, and grow your roster."
                )

                connectCard
                athletesCard
                workoutsCard
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 120)
        }
        .background(
            EmptyView().sheet(isPresented: $showBuilder) {
                WorkoutBuilderSheet()
                    .environment(store)
            }
        )
        .background(
            EmptyView().sheet(isPresented: $showQRConnect) {
                QRConnectSheet(mode: qrStartMode)
                    .environment(store)
            }
        )
    }

    // MARK: Connect

    private var connectCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Connect")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("Grow your roster in person — show your code or scan an athlete's.")
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)

                HStack(spacing: 10) {
                    Button {
                        qrStartMode = .show
                        showQRConnect = true
                    } label: {
                        Label("My Code", systemImage: "qrcode")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))

                    Button {
                        qrStartMode = .scan
                        showQRConnect = true
                    } label: {
                        Label("Scan", systemImage: "qrcode.viewfinder")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryCTAButtonStyle())
                }

                if !store.scannedConnections.isEmpty {
                    Text("\(store.scannedConnections.count) connection\(store.scannedConnections.count == 1 ? "" : "s") saved")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textMuted)
                }
            }
        }
    }

    // MARK: Athletes

    private var athletesCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Find athletes")
                    .font(.headline)
                    .foregroundStyle(.white)

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(MorpheTheme.textMuted)
                    TextField("Search your athletes by name", text: $athleteQuery)
                        .textFieldStyle(.plain)
                        .foregroundStyle(.white)
                        .autocorrectionDisabled()
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                )

                if athleteQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(store.coachClients.isEmpty
                        ? "No athletes yet — connect with a QR code above, and your roster builds from there."
                        : "Search across your \(store.coachClients.count) athlete\(store.coachClients.count == 1 ? "" : "s").")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textMuted)
                } else if athleteResults.isEmpty {
                    Text("No athletes match \"\(athleteQuery)\". Username search across all of Morphe unlocks as account linking rolls out — QR connect works today.")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textMuted)
                } else {
                    ForEach(athleteResults) { athlete in
                        Button {
                            store.openClientHub(athlete)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "figure.run")
                                    .foregroundStyle(MorpheTheme.accent)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(athlete.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                    Text("\(athlete.sport.rawValue) · \(athlete.fitnessLevel)")
                                        .font(.caption)
                                        .foregroundStyle(MorpheTheme.textSecondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(MorpheTheme.textMuted)
                            }
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: Workouts

    private var workoutsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Workouts")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Button(showSavedOnly ? "All" : "Saved") {
                        showSavedOnly.toggle()
                    }
                    .buttonStyle(FilterChipStyle(isSelected: showSavedOnly, selectedColor: MorpheTheme.accent))
                }

                Button {
                    showBuilder = true
                } label: {
                    Label("Build your own workout", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryCTAButtonStyle())

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(MorpheTheme.textMuted)
                    TextField("Search \(store.discoverWorkouts.count) workouts", text: $workoutQuery)
                        .textFieldStyle(.plain)
                        .foregroundStyle(.white)
                        .autocorrectionDisabled()
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                )

                if workoutResults.isEmpty {
                    Text(showSavedOnly
                        ? "Nothing saved yet — browse and tap the bookmark to build your library."
                        : "No workouts match \"\(workoutQuery)\".")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textMuted)
                } else {
                    ForEach(workoutResults) { workout in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(workout.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                Text("\(workout.durationMinutes) min · \(workout.trainingTypeTag.isEmpty ? workout.goal : workout.trainingTypeTag)")
                                    .font(.caption)
                                    .foregroundStyle(MorpheTheme.textSecondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Button {
                                store.saveCatalogWorkout(workout)
                            } label: {
                                Image(systemName: store.isCatalogWorkoutSaved(workout) ? "bookmark.fill" : "bookmark")
                                    .foregroundStyle(store.isCatalogWorkoutSaved(workout) ? MorpheTheme.accent : MorpheTheme.textMuted)
                                    .frame(width: 36, height: 36)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(store.isCatalogWorkoutSaved(workout) ? "Saved" : "Save \(workout.name)")
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }
}
