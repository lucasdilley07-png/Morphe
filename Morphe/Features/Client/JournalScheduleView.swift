import Charts
import SwiftUI

struct ExerciseDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(MorpheAppStore.self) private var store
    let exercise: ExerciseReference
    @State private var showReference = false
    @State private var frames: [UIImage] = []
    @State private var frameIndex = 0

    /// Only alternatives that actually exist in the library — several listed
    /// names have no page, and dead text teaches nothing.
    private var realAlternatives: [ExerciseReference] {
        exercise.alternatives.compactMap { name in
            store.exerciseDatabase.first { $0.name == name }
        }
    }

    /// The page reads top-down the way a lifter uses it (Lucas 2026-10-16):
    /// name → the picture → the steps → one cue → Do / Don't → alternatives,
    /// with the reference folded away at the bottom. Nothing text-heavy
    /// above the fold.
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    if !frames.isEmpty { diagramCard }
                    stepsCard
                    doDontCard
                    if !realAlternatives.isEmpty { alternativesCard }
                    referenceDropdown
                }
                .padding(20)
            }
            .background(PremiumBackground())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(MorpheTheme.textPrimary)
                }
            }
            .task(id: exercise.id) {
                frameIndex = 0
                frames = await FormDiagrams.frames(for: exercise.id)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(exercise.name)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(MorpheTheme.textPrimary)
                Spacer(minLength: 8)
                // Saved exercises live in Learn → Library (Lucas 2026-10-10).
                Button {
                    store.toggleSavedExercise(exercise)
                    Haptics.impact(.light)
                } label: {
                    Image(systemName: store.savedExerciseIDs.contains(exercise.id) ? "bookmark.fill" : "bookmark")
                        .font(.headline)
                        .foregroundStyle(MorpheTheme.accentText)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(store.savedExerciseIDs.contains(exercise.id) ? "Remove from saved exercises" : "Save exercise")
            }
            // One quiet line, not three pills.
            Text([exercise.musclesWorked, exercise.equipment, exercise.difficulty.rawValue]
                    .filter { !$0.isEmpty }.joined(separator: " · "))
                .font(.caption.weight(.semibold))
                .foregroundStyle(MorpheTheme.textSecondary)
            if let baseID = exercise.variationOf,
               let base = store.exerciseDatabase.first(where: { $0.id == baseID }) {
                Button {
                    store.selectedExercise = base
                } label: {
                    HStack(spacing: 6) {
                        Text("Variation of \(base.name)")
                            .font(.caption.weight(.semibold))
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.bold))
                    }
                    .foregroundStyle(MorpheTheme.accentText)
                    .frame(minHeight: 32, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the base movement's form guide")
            }
        }
    }

    /// The step frames (`id-1.heic`, `id-2.heic`, …) page with the steps;
    /// a single `id.heic` shows alone.
    private var diagramCard: some View {
        VStack(spacing: 8) {
            TabView(selection: $frameIndex) {
                ForEach(Array(frames.enumerated()), id: \.offset) { index, image in
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .tag(index)
                        .accessibilityLabel(frames.count > 1
                            ? "Step \(index + 1) of \(frames.count), \(exercise.name)"
                            : "Form diagram for \(exercise.name)")
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .aspectRatio(1, contentMode: .fit)
            if frames.count > 1 {
                HStack(spacing: 6) {
                    ForEach(0..<frames.count, id: \.self) { index in
                        Capsule()
                            .fill(index == frameIndex ? MorpheTheme.accent : MorpheTheme.stroke)
                            .frame(width: index == frameIndex ? 18 : 6, height: 6)
                    }
                    Spacer(minLength: 0)
                    Text("STEP \(frameIndex + 1) OF \(frames.count)")
                        .font(MorpheTheme.microLabel(10)).tracking(1.2)
                        .foregroundStyle(MorpheTheme.textMuted)
                }
                .animation(.easeOut(duration: 0.2), value: frameIndex)
            }
        }
    }

    private var stepsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(exercise.instructions.enumerated()), id: \.offset) { index, step in
                    Button {
                        // Tapping a step pages the diagram to its frame.
                        if frames.count > index { withAnimation { frameIndex = index } }
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text("\(index + 1)")
                                .font(.caption.weight(.bold).monospacedDigit())
                                .foregroundStyle(frames.count > 1 && frameIndex == index ? MorpheTheme.onFill(MorpheTheme.accent) : MorpheTheme.accentText)
                                .frame(width: 22, height: 22)
                                .background(Circle().fill(frames.count > 1 && frameIndex == index ? MorpheTheme.accent : MorpheTheme.accent.opacity(0.12)))
                            Text(step)
                                .font(.subheadline)
                                .foregroundStyle(MorpheTheme.textPrimary)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                if !exercise.formCue.isEmpty {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: "quote.opening")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(MorpheTheme.accentText)
                        Text(exercise.formCue)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(MorpheTheme.accentText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 4)
                    .accessibilityLabel("Cue: \(exercise.formCue)")
                }
            }
        }
    }

    private var doDontCard: some View {
        GlassCard(.quiet) {
            VStack(alignment: .leading, spacing: 10) {
                if !exercise.beginnerModification.isEmpty {
                    row("checkmark.circle.fill", "Do", exercise.beginnerModification, MorpheTheme.accentText)
                }
                if !exercise.commonMistakes.isEmpty {
                    row("xmark.circle.fill", "Don't", exercise.commonMistakes, MorpheTheme.warning)
                }
            }
        }
    }

    private func row(_ symbol: String, _ label: String, _ text: String, _ color: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(color)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(text)")
    }

    private var alternativesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ALSO TRY")
                .font(MorpheTheme.microLabel(10)).tracking(1.4)
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

    /// Where the technique was checked, folded away at the bottom with the
    /// "why" (Lucas 2026-10-16). The words are Morphe's; the source is the
    /// reference they were held against.
    private var referenceDropdown: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showReference.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Text("REFERENCE")
                        .font(MorpheTheme.microLabel(10)).tracking(1.4)
                        .foregroundStyle(MorpheTheme.textMuted)
                    Rectangle().fill(MorpheTheme.strokeSubtle).frame(height: 1)
                    Image(systemName: showReference ? "minus" : "plus")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(MorpheTheme.accentText)
                }
                .frame(minHeight: 36)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(showReference ? "Hide the reference" : "Show the reference")
            if showReference {
                VStack(alignment: .leading, spacing: 8) {
                    if !exercise.whyThisMatters.isEmpty {
                        Text(exercise.whyThisMatters)
                            .font(.subheadline)
                            .foregroundStyle(MorpheTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if !exercise.sourceName.isEmpty {
                        if let url = URL(string: exercise.sourceURL) {
                            Link(destination: url) {
                                HStack(spacing: 6) {
                                    Text(exercise.sourceName)
                                        .font(.subheadline.weight(.semibold))
                                        .multilineTextAlignment(.leading)
                                    Image(systemName: "arrow.up.right")
                                        .font(.caption.weight(.bold))
                                }
                                .foregroundStyle(MorpheTheme.accentText)
                                .frame(minHeight: 44, alignment: .leading)
                            }
                            .accessibilityHint("Opens the source in your browser")
                        } else {
                            Text(exercise.sourceName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(MorpheTheme.textPrimary)
                        }
                    }
                    Text("Morphe's own wording, written with this coaching reference. A training aid, not medical advice.")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .transition(.opacity)
            }
        }
    }
}

/// The bundled form diagrams: step frames `<id>-1.heic … <id>-N.heic`
/// (one per instruction, Lucas 2026-10-16) or the single `<id>.heic`.
enum FormDiagrams {
    nonisolated static func url(forFrame id: String, step: Int) -> URL? {
        Bundle.main.url(forResource: "\(id)-\(step)", withExtension: "heic", subdirectory: "FormDiagrams")
    }

    nonisolated static func frames(for id: String) async -> [UIImage] {
        var result: [UIImage] = []
        var step = 1
        while let url = url(forFrame: id, step: step), let image = UIImage(contentsOfFile: url.path), step <= 12 {
            result.append(image); step += 1
        }
        if result.isEmpty,
           let url = Bundle.main.url(forResource: id, withExtension: "heic", subdirectory: "FormDiagrams"),
           let image = UIImage(contentsOfFile: url.path) {
            result = [image]
        }
        return result
    }

    /// The thumbnail: the first step frame, else the single diagram.
    nonisolated static func thumbnail(for id: String) -> UIImage? {
        if let url = url(forFrame: id, step: 1), let image = UIImage(contentsOfFile: url.path) { return image }
        guard let url = Bundle.main.url(forResource: id, withExtension: "heic", subdirectory: "FormDiagrams") else { return nil }
        return UIImage(contentsOfFile: url.path)
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
/// Shared by the client schedule list (the coach booking card is gone).
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

/// Compact add-appointment editor. "With" can be picked from people this
/// account knows or typed freely — an appointment's other party may not be
/// a Morphe account at all.
struct AppointmentEditorSheet: View {
    @Environment(MorpheAppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

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
                            .tint(MorpheTheme.accentText)

                            DatePicker("Time", selection: $date, in: .now...)
                                .tint(MorpheTheme.accentText)
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
