import SwiftUI

// MARK: - Client: book & pay for a session with a coach

/// The client-facing booking flow: pick a training package, pick an open time,
/// review, and request the booking. Real payment connects with the backend —
/// until then the charge is deferred and the UI says so plainly.
struct CoachBookingSheet: View {
    @Environment(MorpheAppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let coachName: String

    @State private var selectedPackageID: UUID?
    @State private var selectedSlotID: UUID?

    private var packages: [TrainingPackage] { store.trainingPackages }
    private var slots: [AvailabilitySlot] { store.openAvailabilitySlots }

    private var selectedPackage: TrainingPackage? {
        packages.first { $0.id == selectedPackageID }
    }

    private var selectedSlot: AvailabilitySlot? {
        slots.first { $0.id == selectedSlotID }
    }

    private var canBook: Bool {
        selectedPackage != nil && selectedSlot != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    SectionTitleView(
                        title: "Train with \(coachName)",
                        subtitle: "Pick a package and a time. You'll confirm before anything is charged."
                    )

                    if packages.isEmpty {
                        emptyCatalog
                    } else {
                        packageSection
                        if !slots.isEmpty {
                            slotSection
                        }
                        checkoutSection
                    }
                }
                .padding(20)
                .padding(.bottom, 40)
            }
            .background(PremiumBackground().ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
    }

    private var emptyCatalog: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("No packages yet")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("\(coachName) hasn't published training packages yet. Check back soon or send a message.")
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var packageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose a package")
                .font(.headline)
                .foregroundStyle(.white)

            ForEach(packages) { package in
                BookingPackageCard(
                    package: package,
                    isSelected: package.id == selectedPackageID
                ) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedPackageID = package.id
                    }
                }
            }
        }
    }

    private var slotSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pick a time")
                .font(.headline)
                .foregroundStyle(.white)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 10)], spacing: 10) {
                ForEach(slots) { slot in
                    BookingSlotChip(
                        slot: slot,
                        isSelected: slot.id == selectedSlotID
                    ) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedSlotID = slot.id
                        }
                    }
                }
            }
        }
    }

    private var checkoutSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Summary")
                        .font(.headline)
                        .foregroundStyle(.white)

                    CheckoutRow(label: "Coach", value: coachName)
                    CheckoutRow(label: "Package", value: selectedPackage?.title ?? "—")
                    CheckoutRow(
                        label: "Time",
                        value: selectedSlot.map { "\($0.day) · \($0.time)" } ?? "—"
                    )

                    Divider().overlay(MorpheTheme.stroke)

                    HStack {
                        Text("Total")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Spacer()
                        Text(selectedPackage?.price ?? "$0")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(MorpheTheme.accent)
                    }
                }
            }

            // Honest about money: nothing is charged until payments connect.
            Label(
                store.paymentsEnabled
                    ? "You'll be charged when the coach confirms."
                    : "Card payments connect at launch — for now this sends a booking request, no charge.",
                systemImage: "lock.shield"
            )
            .font(.caption)
            .foregroundStyle(MorpheTheme.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                guard let package = selectedPackage, let slot = selectedSlot else { return }
                store.requestSessionBooking(package: package, slot: slot, coachName: coachName)
                dismiss()
            } label: {
                Text(store.paymentsEnabled ? "Book" : "Request Booking")
            }
            .buttonStyle(PrimaryCTAButtonStyle())
            .accessibilityLabel(store.paymentsEnabled
                ? "Book and pay \(selectedPackage?.price ?? "")"
                : "Request to book, no charge")
            .disabled(!canBook)
            .opacity(canBook ? 1 : 0.5)
        }
    }
}

private struct BookingPackageCard: View {
    let package: TrainingPackage
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(package.title)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.white)
                                if package.isPopular {
                                    Text("POPULAR")
                                        .font(.caption2.weight(.heavy))
                                        .foregroundStyle(.black)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Capsule().fill(MorpheTheme.accent))
                                }
                            }
                            Text(package.perSessionLabel)
                                .font(.caption)
                                .foregroundStyle(MorpheTheme.textMuted)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(package.price)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(isSelected ? MorpheTheme.accent : .white)
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(isSelected ? MorpheTheme.accent : MorpheTheme.textMuted)
                        }
                    }

                    Text(package.summary)
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                    .stroke(isSelected ? MorpheTheme.accent.opacity(0.6) : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

private struct BookingSlotChip: View {
    let slot: AvailabilitySlot
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 2) {
                Text(slot.day)
                    .font(.caption.weight(.bold))
                Text(slot.time)
                    .font(.caption2)
            }
            .foregroundStyle(isSelected ? .black : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                    .fill(isSelected ? MorpheTheme.accent : MorpheTheme.panel)
            )
            .overlay(
                RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                    .stroke(MorpheTheme.strokeStrong.opacity(isSelected ? 0 : 0.4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(slot.day) at \(slot.time)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

private struct CheckoutRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(MorpheTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Client: my booked sessions

/// A compact list of the client's booked sessions for the profile/hub.
struct MyBookingsCard: View {
    @Environment(MorpheAppStore.self) private var store

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("My Sessions")
                    .font(.headline)
                    .foregroundStyle(.white)

                if store.myUpcomingBookings.isEmpty {
                    Text("No booked sessions yet. Find a coach to train with and book your first.")
                        .font(.subheadline)
                        .foregroundStyle(MorpheTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(store.myUpcomingBookings) { booking in
                        BookingRow(booking: booking)
                    }
                }
            }
        }
    }
}

private struct BookingRow: View {
    let booking: SessionBooking

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.headline)
                .foregroundStyle(MorpheTheme.accentAlt)
                .frame(width: 40, height: 40)
                .background(RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous).fill(MorpheTheme.panelStrong))

            VStack(alignment: .leading, spacing: 3) {
                Text(booking.packageTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text("\(booking.coachName) · \(booking.day) \(booking.time)")
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textSecondary)
            }

            Spacer(minLength: 0)

            StatusPill(text: booking.status.rawValue, tint: statusTint(booking.status))
        }
        .accessibilityElement(children: .combine)
    }

    private func statusTint(_ status: BookingStatus) -> Color {
        switch status {
        case .requested: return MorpheTheme.warning
        case .confirmed: return MorpheTheme.accent
        case .completed: return MorpheTheme.textMuted
        case .cancelled: return MorpheTheme.danger
        }
    }
}

private struct StatusPill: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(tint.opacity(0.16)))
    }
}

// MARK: - Coach: training business

/// The coach's commerce surface: earnings, booking requests to confirm, and the
/// packages they sell. Payout setup connects with the backend.
struct CoachBusinessView: View {
    @Environment(MorpheAppStore.self) private var store
    @State private var showAddAppointment = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                SectionTitleView(
                    title: "Training Business",
                    subtitle: "Your schedule and, once payments connect, your rates and earnings."
                )

                appointmentsCard

                // The demo commerce surfaces (packages, slots, earnings,
                // booking requests) are hidden for the solo-first launch:
                // they run on seeded data and can't take real money yet.
                // They return with marketplace payments — see docs/PAYMENTS.md.
                if FeatureFlags.multiUserEnabled {
                    earningsCard
                    if !store.coachBookingRequests.isEmpty {
                        requestsCard
                    }
                    packagesCard
                    payoutCard
                }
            }
            .padding(20)
            .padding(.bottom, 120)
        }
        .background(PremiumBackground().ignoresSafeArea())
        .sheet(isPresented: $showAddAppointment) {
            // The coach can pick "With" from their managed roster or type a
            // name — there is no live coach↔client account link yet, so the
            // other party may not be on Morphe at all.
            AppointmentEditorSheet(nameSuggestions: store.managedClients.map(\.name))
                .environment(store)
        }
    }

    /// The coach's REAL session management: personal appointments that sync
    /// per account (unlike the seeded booking demo below, which is gated).
    private var appointmentsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Upcoming Appointments")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Button("Add") { showAddAppointment = true }
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(MorpheTheme.accent))
                        .accessibilityLabel("Add appointment")
                }

                if store.upcomingAppointments.isEmpty {
                    Text("Nothing scheduled. Add sessions, check-ins, or assessments — they sync to your account.")
                        .font(.subheadline)
                        .foregroundStyle(MorpheTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(store.upcomingAppointments) { appointment in
                        HStack(spacing: 8) {
                            AppointmentRowView(appointment: appointment)
                            Menu {
                                Button("Complete") {
                                    store.updateAppointmentStatus(appointment, to: Appointment.statusCompleted)
                                }
                                Button("Cancel") {
                                    store.updateAppointmentStatus(appointment, to: Appointment.statusCancelled)
                                }
                                Button("Delete", role: .destructive) {
                                    store.deleteAppointment(appointment)
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .foregroundStyle(MorpheTheme.textSecondary)
                            }
                            .accessibilityLabel("Appointment actions for \(appointment.title)")
                        }
                    }
                }
            }
        }
    }

    private var earningsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Earnings")
                    .font(.headline)
                    .foregroundStyle(.white)

                HStack(spacing: 12) {
                    EarningsStat(label: "Paid", value: dollars(store.coachPaidEarnings), tint: MorpheTheme.accent)
                    EarningsStat(label: "Pending", value: dollars(store.coachPendingEarnings), tint: MorpheTheme.warning)
                }
            }
        }
    }

    private var requestsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Booking Requests")
                    .font(.headline)
                    .foregroundStyle(.white)

                ForEach(store.coachBookingRequests) { booking in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(booking.clientName) · \(booking.packageTitle)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Text("\(booking.day) \(booking.time) · \(booking.price)")
                                .font(.caption)
                                .foregroundStyle(MorpheTheme.textSecondary)
                        }
                        Spacer(minLength: 0)
                        Button("Confirm") {
                            store.confirmBooking(booking)
                        }
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(MorpheTheme.accent))
                    }
                }
            }
        }
    }

    private var packagesCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Your Packages")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(store.trainingPackages.count)")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(MorpheTheme.textMuted)
                }

                if store.trainingPackages.isEmpty {
                    Text("Add a package so clients can book and pay you for sessions.")
                        .font(.subheadline)
                        .foregroundStyle(MorpheTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(store.trainingPackages) { package in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(package.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                Text(package.perSessionLabel)
                                    .font(.caption)
                                    .foregroundStyle(MorpheTheme.textMuted)
                            }
                            Spacer()
                            Text(package.price)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(MorpheTheme.accent)
                        }
                    }
                }
            }
        }
    }

    private var payoutCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("Payouts", systemImage: "banknote")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Connect a payout account to get paid directly. Secure payments and payouts turn on at launch.")
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Payouts") {}
                    .accessibilityLabel("Set up payouts")
                    .buttonStyle(SecondaryCTAButtonStyle())
                    .disabled(true)
                    .opacity(0.5)
            }
        }
    }

    private func dollars(_ value: Double) -> String {
        "$\(Int(value.rounded()))"
    }
}

private struct EarningsStat: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(tint)
            Text(label)
                .font(.caption)
                .foregroundStyle(MorpheTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous).fill(MorpheTheme.panelStrong))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}
