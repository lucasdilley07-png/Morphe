import Charts
import SwiftUI

struct ExerciseDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(MorpheAppStore.self) private var store
    let exercise: ExerciseReference

    /// Only alternatives that actually exist in the library — several listed
    /// names have no page, and dead text teaches nothing.
    private var realAlternatives: [ExerciseReference] {
        exercise.alternatives.compactMap { name in
            store.exerciseDatabase.first { $0.name == name }
        }
    }

    /// The exercise's form diagram from the bundled FormDiagrams folder.
    /// Nil (and the card simply doesn't render) for exercises without one —
    /// custom user-created exercises have no diagram.
    private var formDiagram: UIImage? {
        guard let url = Bundle.main.url(
            forResource: exercise.id,
            withExtension: "heic",
            subdirectory: "FormDiagrams"
        ) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(exercise.name)
                                .font(.title2.weight(.bold))
                                .foregroundStyle(MorpheTheme.textPrimary)

                            HStack(spacing: 8) {
                                MetricPill(label: "Muscles", value: exercise.musclesWorked)
                                MetricPill(label: "Gear", value: exercise.equipment)
                            }

                            MetricPill(label: "Difficulty", value: exercise.difficulty.rawValue)

                            if !exercise.whyThisMatters.isEmpty {
                                Text(exercise.whyThisMatters)
                                    .font(.subheadline)
                                    .foregroundStyle(MorpheTheme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    if let formDiagram {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Form Diagram")
                                    .font(.headline)
                                    .foregroundStyle(MorpheTheme.textPrimary)

                                Image(uiImage: formDiagram)
                                    .resizable()
                                    .scaledToFit()
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .accessibilityLabel("Form diagram for \(exercise.name)")
                            }
                        }
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Step-by-step form instructions")
                                .font(.headline)
                                .foregroundStyle(MorpheTheme.textPrimary)

                            ForEach(exercise.instructions, id: \.self) { step in
                                Text("- \(step)")
                                    .foregroundStyle(MorpheTheme.textPrimary)
                            }
                        }
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Coach Cue")
                                .font(.headline)
                                .foregroundStyle(MorpheTheme.textPrimary)
                            Text(exercise.formCue)
                                .foregroundStyle(MorpheTheme.textPrimary)

                            Text("Common Mistake")
                                .font(.headline)
                                .foregroundStyle(MorpheTheme.textPrimary)
                            Text(exercise.commonMistakes)
                                .foregroundStyle(MorpheTheme.textSecondary)

                            Text("Beginner Modification")
                                .font(.headline)
                                .foregroundStyle(MorpheTheme.textPrimary)
                            Text(exercise.beginnerModification)
                                .foregroundStyle(MorpheTheme.textSecondary)
                        }
                    }

                    if !realAlternatives.isEmpty {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Alternative Exercises")
                                    .font(.headline)
                                    .foregroundStyle(MorpheTheme.textPrimary)
                                Text("Tap one to open its form guide.")
                                    .font(.caption)
                                    .foregroundStyle(MorpheTheme.textMuted)

                                WrapStack(spacing: 8) {
                                    ForEach(realAlternatives) { alternative in
                                        Button(alternative.name) {
                                            // Swaps the sheet's content in place.
                                            store.selectedExercise = alternative
                                        }
                                        .buttonStyle(FilterChipStyle(isSelected: false, selectedColor: MorpheTheme.accentAlt))
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(PremiumBackground())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(MorpheTheme.textPrimary)
                }
            }
        }
    }
}


private enum AthleteProfileAnchor: String, Hashable {
    case workoutInput
    case completedLogs
}












// Internal (not private): the athlete-side Workout History reuses this
// editor for own-log corrections — one editor, both roles.
struct WorkoutLogEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: WorkoutLog
    let title: String
    let subtitle: String
    let confirmLabel: String
    let onConfirm: (WorkoutLog) -> Void

    init(
        draft: WorkoutLog,
        title: String,
        subtitle: String,
        confirmLabel: String,
        onConfirm: @escaping (WorkoutLog) -> Void
    ) {
        _draft = State(initialValue: draft)
        self.title = title
        self.subtitle = subtitle
        self.confirmLabel = confirmLabel
        self.onConfirm = onConfirm
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(title)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(MorpheTheme.textPrimary)

                            Text(subtitle)
                                .foregroundStyle(MorpheTheme.textSecondary)

                            HStack(spacing: 8) {
                                MetricPill(label: "Athlete", value: draft.athleteName)
                                MetricPill(label: "Source", value: draft.source.rawValue)
                                MetricPill(label: "Status", value: draft.verificationStatus.rawValue)
                            }
                        }
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Workout Details")
                                .font(.headline)
                                .foregroundStyle(MorpheTheme.textPrimary)

                            TextField("Workout title", text: $draft.workoutTitle)
                                .textFieldStyle(MorpheFieldStyle())

                            Stepper("Duration: \(draft.durationMinutes) min", value: $draft.durationMinutes, in: 5...180, step: 5)
                                .foregroundStyle(MorpheTheme.textPrimary)

                            TextField("Review notes", text: $draft.notes, axis: .vertical)
                                .textFieldStyle(MorpheFieldStyle())
                                .lineLimit(3...5)
                        }
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Parsed Exercises")
                                .font(.headline)
                                .foregroundStyle(MorpheTheme.textPrimary)

                            ForEach($draft.exercises) { $exercise in
                                VStack(alignment: .leading, spacing: 10) {
                                    TextField("Exercise name", text: $exercise.name)
                                        .textFieldStyle(MorpheFieldStyle())

                                    HStack(spacing: 10) {
                                        TextField("Sets", text: $exercise.sets)
                                            .textFieldStyle(MorpheFieldStyle())
                                        TextField("Reps", text: $exercise.reps)
                                            .textFieldStyle(MorpheFieldStyle())
                                        TextField("Weight", text: $exercise.weight)
                                            .textFieldStyle(MorpheFieldStyle())
                                    }

                                    TextField("Exercise note", text: $exercise.note, axis: .vertical)
                                        .textFieldStyle(MorpheFieldStyle())
                                        .lineLimit(2...4)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }

                    Button(confirmLabel) {
                        onConfirm(draft)
                        dismiss()
                    }
                    .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                }
                .padding(20)
            }
            .background(PremiumBackground())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(MorpheTheme.textPrimary)
                }
            }
        }
    }
}


private enum CoachWorkoutLogFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case athlete = "Athlete"
    case coach = "Coach"
    case ai = "AI"
    case buddy = "Buddy"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .all:
            return MorpheTheme.accent
        case .athlete:
            return MorpheTheme.accent
        case .coach:
            return MorpheTheme.accentAlt
        case .ai:
            return MorpheTheme.lavender
        case .buddy:
            return MorpheTheme.warning
        }
    }

    var emptyStateMessage: String {
        switch self {
        case .all:
            return "No shared logs yet."
        case .athlete:
            return "No athlete-entered logs yet."
        case .coach:
            return "No coach-entered logs yet."
        case .ai:
            return "No AI-imported logs yet."
        case .buddy:
            return "No buddy sessions have been logged yet."
        }
    }
}

struct ProgramComplianceCard: View {
    let compliance: ProgramCompliance

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Program Compliance")
                    .font(.headline)
                    .foregroundStyle(MorpheTheme.textPrimary)
                Text("\(compliance.score)%")
                    .font(.system(.title, design: .monospaced).weight(.bold))
                    .foregroundStyle(MorpheTheme.textPrimary)
                Text(compliance.summary)
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)
            }
        }
    }
}











private struct ProfileLine: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(MorpheTheme.textMuted)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(MorpheTheme.textPrimary)
        }
    }
}

// MARK: - Appointments (real personal schedule)

/// One appointment line: kind icon, title, when, and who it's with.
/// Shared by the client schedule list and the coach's card in BookingView.
struct AppointmentRowView: View {
    let appointment: Appointment

    private var whenLabel: String {
        appointment.date.formatted(date: .abbreviated, time: .shortened)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: appointment.kind.systemImage)
                .font(.headline)
                .foregroundStyle(MorpheTheme.accentAlt)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                        .fill(MorpheTheme.panelStrong)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(appointment.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MorpheTheme.textPrimary)
                HStack(spacing: 4) {
                    Text(appointment.withName.isEmpty
                        ? "\(whenLabel) · \(appointment.durationMinutes) min"
                        : "\(whenLabel) · \(appointment.durationMinutes) min · \(appointment.withName)")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textSecondary)
                    if appointment.withUid != nil {
                        // Picked from known people — a real profile link,
                        // not just a typed name.
                        Image(systemName: "link")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(MorpheTheme.accentText)
                            .accessibilityLabel("Linked profile")
                    }
                }
            }

            Spacer(minLength: 0)

            StatusBadge(text: appointment.kind.title, color: MorpheTheme.accent)
        }
        .accessibilityElement(children: .combine)
    }
}

/// The client's schedule surface: upcoming appointments as a swipeable list.
/// Swipe an appointment to cancel it (soft — the doc keeps its history) or
/// remove it entirely; "+ Add" opens the compact editor.
struct ClientAppointmentsView: View {
    @Environment(MorpheAppStore.self) private var store
    @State private var showAddSheet = false

    var body: some View {
        List {
            Section {
                if store.upcomingAppointments.isEmpty {
                    Text("Nothing scheduled. Add a session, check-in, or anything you train around.")
                        .font(.subheadline)
                        .foregroundStyle(MorpheTheme.textSecondary)
                        .listRowBackground(MorpheTheme.panel)
                } else {
                    ForEach(store.upcomingAppointments) { appointment in
                        AppointmentRowView(appointment: appointment)
                            .listRowBackground(MorpheTheme.panel)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Delete", role: .destructive) {
                                    store.deleteAppointment(appointment)
                                }
                                Button("Cancel") {
                                    store.updateAppointmentStatus(appointment, to: Appointment.statusCancelled)
                                }
                                .tint(MorpheTheme.warning)
                            }
                    }
                }
            } header: {
                Text("Appointments")
                    .font(.headline)
                    .foregroundStyle(MorpheTheme.textPrimary)
                    .textCase(nil)
            }
        }
        .scrollContentBackground(.hidden)
        .background(PremiumBackground().ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add") { showAddSheet = true }
                    .foregroundStyle(MorpheTheme.accentText)
                    .accessibilityLabel("Add appointment")
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AppointmentEditorSheet()
                .environment(store)
        }
    }
}

/// Compact add-appointment editor, shared by client and coach. The coach
/// passes `nameSuggestions` (managed client names) so "With" can be picked
/// from the roster or typed freely — an appointment's other party may not be
/// a Morphe account at all.
struct AppointmentEditorSheet: View {
    @Environment(MorpheAppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var nameSuggestions: [String] = []

    @State private var title = ""
    @State private var kind: AppointmentKind = .session
    @State private var date = Date.now.addingTimeInterval(60 * 60)
    @State private var durationMinutes = 60
    @State private var withName = ""
    /// Set when "With" was PICKED from known people — the appointment
    /// links to that account/connection. Typing over the picked name
    /// clears the link (free text may not be a Morphe person at all).
    @State private var withUid: String?
    @State private var notes = ""

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("New Appointment")
                                .font(.headline)
                                .foregroundStyle(MorpheTheme.textPrimary)

                            TextField("Title", text: $title)
                                .textFieldStyle(MorpheFieldStyle())

                            Picker("Kind", selection: $kind) {
                                ForEach(AppointmentKind.allCases) { kind in
                                    Label(kind.title, systemImage: kind.systemImage).tag(kind)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(MorpheTheme.accent)

                            DatePicker("Time", selection: $date, in: .now...)
                                .tint(MorpheTheme.accent)
                                .foregroundStyle(MorpheTheme.textPrimary)

                            Stepper("Duration: \(durationMinutes) min", value: $durationMinutes, in: 15...240, step: 15)
                                .foregroundStyle(MorpheTheme.textPrimary)
                        }
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("With")
                                .font(.headline)
                                .foregroundStyle(MorpheTheme.textPrimary)

                            TextField("Who it's with (optional)", text: $withName)
                                .textFieldStyle(MorpheFieldStyle())
                                .onChange(of: withName) { _, newValue in
                                    // Editing away from the picked person
                                    // breaks the link — free text may not
                                    // be a Morphe account at all.
                                    if let linked = store.appointmentPeopleChoices.first(where: { $0.id == withUid }),
                                       linked.name != newValue {
                                        withUid = nil
                                    }
                                }

                            // Every person this account knows — connections,
                            // partners, roster — pickable so the session
                            // links to a real profile, not just a string.
                            if !store.appointmentPeopleChoices.isEmpty {
                                Menu {
                                    ForEach(store.appointmentPeopleChoices) { person in
                                        Button("\(person.name) — \(person.detail)") {
                                            withName = person.name
                                            withUid = person.id
                                        }
                                    }
                                } label: {
                                    Label("Pick Person", systemImage: "person.crop.circle.badge.checkmark")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(MorpheTheme.accentAlt)
                                }
                            }

                            if withUid != nil {
                                Label("Linked to their profile", systemImage: "link")
                                    .font(.caption)
                                    .foregroundStyle(MorpheTheme.accentText)
                                    .accessibilityLabel("Appointment linked to \(withName)'s profile")
                            }

                            if !nameSuggestions.isEmpty {
                                Menu {
                                    ForEach(nameSuggestions, id: \.self) { name in
                                        Button(name) { withName = name }
                                    }
                                } label: {
                                    Label("Pick Client", systemImage: "person.crop.circle.badge.checkmark")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(MorpheTheme.accentAlt)
                                }
                            }

                            TextField("Notes (optional)", text: $notes, axis: .vertical)
                                .textFieldStyle(MorpheFieldStyle())
                                .lineLimit(2...4)
                        }
                    }

                    Button("Save") {
                        store.addAppointment(
                            title: title,
                            date: date,
                            durationMinutes: durationMinutes,
                            kind: kind,
                            withName: withName,
                            withUid: withUid,
                            notes: notes
                        )
                        dismiss()
                    }
                    .buttonStyle(PrimaryCTAButtonStyle())
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.5)
                    .accessibilityLabel("Save appointment")
                }
                .padding(20)
            }
            .background(PremiumBackground())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(MorpheTheme.textPrimary)
                }
            }
        }
        .presentationDetents([.large])
    }
}
