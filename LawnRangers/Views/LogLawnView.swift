import SwiftUI

/// "Log a Lawn" — mirrors the "Lawn Mowing Wizard - 2025 Daily Log" form.
/// The look is a modern card layout; the questions, fields, answers, and the data
/// it submits are unchanged from the original Google Form.
struct LogLawnView: View {
    @Environment(\.dismiss) private var dismiss

    /// When set, the form edits this existing entry (found in the sheet by its
    /// timestamp) instead of creating a new one.
    var editingLawn: SheetLawn? = nil
    @State private var didPrefill = false

    /// Customer names from the live sheet data (passed in by the Lawns tab), so
    /// the "Where?" dropdown reflects customers already in use across the team.
    var knownCustomers: [String] = []

    /// Recent lawns from the live sheet, used to warn when the same customer is
    /// logged twice on the same day (the warning can be bypassed).
    var recentLawns: [SheetLawn] = []

    /// Pre-selects this customer in "Where?" (used when starting from a planned job).
    var initialCustomer: String? = nil
    /// Called after a successful submit (e.g. to clear the originating planned job).
    var onComplete: (() -> Void)? = nil

    /// Customer names fetched live from the sheet's Customers tab, so the
    /// dropdown always reflects the real roster (including just-added customers).
    @State private var sheetCustomers: [String] = []

    // Q1 — Where?
    private static let otherTag = "__other__"
    @State private var whereSelection: String = ""      // "" = none chosen yet
    @State private var whereCustom: String = ""

    // Q2 — Who?
    @State private var selectedTeam: Set<String> = []
    @State private var whoOtherEnabled = false
    @State private var whoOther: String = ""

    // Q3 — How much?  Left empty so the field shows a grayed "Standard"
    // placeholder; an untouched field submits as "Standard" (see resolvedHowMuch),
    // and tapping in gives a blank field to type an actual rate.
    @State private var howMuch: String = ""

    // Q4 / Q5 — Paid?
    @State private var customerPaid: String = ""        // "Paid" / "Unpaid"
    @State private var teammemberPaid: String = ""      // "Paid" / "Unpaid"

    // Q6 — Note
    @State private var note: String = ""

    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showingDuplicateWarning = false
    @FocusState private var whereCustomFocused: Bool
    @FocusState private var whoOtherFocused: Bool

    private let teamMembers = ["Grantham", "Gresham", "Caleb", "Oliver"]

    /// Customers tab ∪ names on logged lawns — all from the sheet, no local data.
    private var allCustomers: [String] {
        Array(Set(sheetCustomers + knownCustomers)).sorted()
    }

    private var resolvedWhere: String {
        whereSelection == Self.otherTag
            ? whereCustom.trimmingCharacters(in: .whitespacesAndNewlines)
            : whereSelection
    }

    private var canSave: Bool {
        !resolvedWhere.isEmpty
            && !resolvedTeam.isEmpty
            && !customerPaid.isEmpty
            && !teammemberPaid.isEmpty
    }

    /// The rate to record: a typed value, or "Standard" if left blank.
    private var resolvedHowMuch: String {
        let trimmed = howMuch.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Standard" : trimmed
    }

    private var resolvedTeam: [String] {
        var team = teamMembers.filter { selectedTeam.contains($0) }
        let other = whoOther.trimmingCharacters(in: .whitespacesAndNewlines)
        if whoOtherEnabled && !other.isEmpty { team.append(other) }
        return team
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let errorMessage {
                        errorBanner(errorMessage)
                    }

                    // Q1 — Where?
                    fieldCard(icon: "mappin.and.ellipse", title: "Where?", required: true) {
                        Menu {
                            Picker("Where?", selection: $whereSelection) {
                                Text("Choose").tag("")
                                ForEach(allCustomers, id: \.self) { Text($0).tag($0) }
                                Text("New customer…").tag(Self.otherTag)
                            }
                        } label: {
                            menuLabel(whereMenuText, isPlaceholder: whereSelection.isEmpty)
                        }
                        .onChange(of: whereSelection) { _, newValue in
                            // Auto-focus the new-customer field (pop keyboard) when chosen.
                            if newValue == Self.otherTag {
                                DispatchQueue.main.async { whereCustomFocused = true }
                            }
                        }
                        if whereSelection == Self.otherTag {
                            inputField {
                                TextField("New customer name", text: $whereCustom)
                                    .textInputAutocapitalization(.words)
                                    .focused($whereCustomFocused)
                            }
                        }
                    }

                    // Q2 — Who?
                    fieldCard(icon: "person.2.fill", title: "Who?", required: true) {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
                            ForEach(teamMembers, id: \.self) { member in
                                chip(member, selected: selectedTeam.contains(member)) {
                                    toggle(member, in: &selectedTeam)
                                }
                            }
                            chip("Other", selected: whoOtherEnabled) {
                                whoOtherEnabled.toggle()
                                // Auto-focus the field (pop keyboard) when turning Other on.
                                if whoOtherEnabled {
                                    DispatchQueue.main.async { whoOtherFocused = true }
                                } else {
                                    whoOtherFocused = false
                                }
                            }
                        }
                        if whoOtherEnabled {
                            inputField {
                                TextField("Other", text: $whoOther)
                                    .textInputAutocapitalization(.words)
                                    .focused($whoOtherFocused)
                            }
                        }
                    }

                    // Q3 — How much?
                    fieldCard(icon: "dollarsign.circle.fill", title: "How much?", required: true) {
                        inputField {
                            TextField("Standard", text: $howMuch)
                        }
                        Text("Defaults to “Standard” (the customer’s standard rate) — tap to type an actual amount.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Q4 — Customer paid?
                    fieldCard(icon: "creditcard.fill", title: "Customer paid?", required: true) {
                        pillPicker($customerPaid)
                    }

                    // Q5 — Teammember paid?
                    fieldCard(icon: "banknote.fill", title: "Teammember paid?", required: true) {
                        pillPicker($teammemberPaid)
                    }

                    // Q6 — Note (optional)
                    fieldCard(icon: "note.text", title: "Note", required: false) {
                        inputField {
                            TextField("Address & phone for new customers", text: $note, axis: .vertical)
                                .lineLimit(3...6)
                        }
                    }
                }
                .padding(16)
            }
            .background(backdrop)
            .navigationTitle(editingLawn == nil ? "Log a Lawn" : "Edit Lawn")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Button(editingLawn == nil ? "Submit" : "Save") { save() }
                            .fontWeight(.semibold)
                            .disabled(!canSave)
                    }
                }
            }
            .onAppear { prefillIfNeeded() }
            .task {
                // Pull the roster from the sheet's Customers tab (best effort —
                // the dropdown still has the names off logged lawns meanwhile).
                if let customers = try? await CustomerService.fetch() {
                    sheetCustomers = customers.map(\.customer).filter { !$0.isEmpty }
                }
            }
            .alert("Already logged today", isPresented: $showingDuplicateWarning) {
                Button("Log Anyway") { performSave() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("\(resolvedWhere) already has a lawn logged today. Log another?")
            }
        }
    }

    // MARK: - Styled building blocks

    private var backdrop: some View {
        LinearGradient(
            colors: [Color(.systemBackground), Color.lawnGreen.opacity(0.10)],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    /// A titled card hosting one question's control(s).
    private func fieldCard<Content: View>(
        icon: String,
        title: String,
        required: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(Color.lawnGreen)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if required {
                    Text("Required")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func menuLabel(_ text: String, isPlaceholder: Bool) -> some View {
        HStack {
            Text(text)
                .foregroundStyle(isPlaceholder ? .secondary : .primary)
            Spacer()
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(fieldFill)
    }

    @ViewBuilder
    private func inputField<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(fieldFill)
    }

    private var fieldFill: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.primary.opacity(0.06))
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(selected ? Color.white : Color.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Capsule().fill(selected ? Color.lawnGreen : Color.primary.opacity(0.06)))
                .overlay(Capsule().stroke(Color.white.opacity(selected ? 0 : 0.08), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func pillPicker(_ selection: Binding<String>) -> some View {
        HStack(spacing: 10) {
            paidPill("Paid", selection: selection, tint: Color.lawnGreen)
            paidPill("Unpaid", selection: selection, tint: Color.orange)
        }
    }

    private func paidPill(_ option: String, selection: Binding<String>, tint: Color) -> some View {
        let isOn = selection.wrappedValue == option
        return Button {
            selection.wrappedValue = option
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.footnote)
                Text(option)
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(isOn ? Color.white : Color.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(Capsule().fill(isOn ? tint : Color.primary.opacity(0.06)))
            .overlay(Capsule().stroke(Color.white.opacity(isOn ? 0 : 0.08), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(message).font(.subheadline)
            Spacer()
        }
        .foregroundStyle(.white)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.red.opacity(0.85))
        )
    }

    private var whereMenuText: String {
        if whereSelection.isEmpty { return "Choose a customer" }
        if whereSelection == Self.otherTag { return "New customer…" }
        return whereSelection
    }

    // MARK: - Edit prefill

    /// On first appearance in edit mode, populate the form from the entry.
    private func prefillIfNeeded() {
        guard !didPrefill else { return }
        didPrefill = true

        // Starting a new lawn from a planned job: just pre-select the customer.
        guard let e = editingLawn else {
            if let c = initialCustomer, !c.isEmpty {
                if allCustomers.contains(c) {
                    whereSelection = c
                } else {
                    whereSelection = Self.otherTag
                    whereCustom = c
                }
            }
            return
        }

        let w = e.whereLocation ?? ""
        if allCustomers.contains(w) {
            whereSelection = w
        } else if !w.isEmpty {
            whereSelection = Self.otherTag
            whereCustom = w
        }

        let names = (e.who ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        var others: [String] = []
        for name in names {
            if teamMembers.contains(name) { selectedTeam.insert(name) }
            else { others.append(name) }
        }
        if !others.isEmpty {
            whoOtherEnabled = true
            whoOther = others.joined(separator: ", ")
        }

        let amount = e.howMuch ?? ""
        // Show the grayed "Standard" placeholder (empty field) for Standard/blank
        // rates; otherwise pre-fill the actual amount.
        howMuch = (amount.isEmpty || amount == "Standard") ? "" : amount
        customerPaid = e.customerPaid ?? ""
        teammemberPaid = e.teammemberPaid ?? ""
        note = e.note ?? ""
    }

    private func toggle(_ value: String, in set: inout Set<String>) {
        if set.contains(value) { set.remove(value) } else { set.insert(value) }
    }

    // MARK: - Save

    /// True when a lawn for the chosen customer was already logged today
    /// (matched case/space-insensitively against the live sheet data).
    private var isDuplicateToday: Bool {
        let target = resolvedWhere.lowercased()
        guard !target.isEmpty else { return false }
        return recentLawns.contains { lawn in
            guard let ts = lawn.ts,
                  let name = lawn.whereLocation?
                      .trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                  name == target
            else { return false }
            return Calendar.current.isDateInToday(Date(timeIntervalSince1970: ts / 1000))
        }
    }

    private func save() {
        // Same-day duplicate guard (new entries only): warn once, allow bypass.
        if editingLawn == nil && isDuplicateToday {
            showingDuplicateWarning = true
            return
        }
        performSave()
    }

    private func performSave() {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)

        let payload: [String: Any]
        if let e = editingLawn, let ts = e.ts {
            // Edit mode: update the existing sheet row, matched by its timestamp.
            payload = [
                "type": "lawnUpdate",
                "ts": ts,
                "where": resolvedWhere,
                "who": resolvedTeam.joined(separator: ", "),
                "howMuch": resolvedHowMuch,
                "customerPaid": customerPaid,
                "teammemberPaid": teammemberPaid,
                "note": trimmedNote,
            ]
        } else {
            // Create mode: append a new entry.
            let log = LawnLog(
                whereLocation: resolvedWhere,
                who: resolvedTeam,
                howMuch: resolvedHowMuch,
                customerPaid: customerPaid,
                teammemberPaid: teammemberPaid,
                note: trimmedNote
            )
            payload = log.sheetPayload()
        }

        // Only dismiss once the save is confirmed; on failure keep the form open
        // with an error so a mow is never silently lost.
        Task {
            isSubmitting = true
            errorMessage = nil
            let result = await SheetSubmitter.submit(payload)
            isSubmitting = false
            switch result {
            case .success:
                onComplete?()
                dismiss()
            case .notConfigured:
                errorMessage = "No backend connected — add the Web App URL in Settings."
            case .failure:
                errorMessage = "Couldn't save — check your connection and try again."
            }
        }
    }
}

#Preview {
    LogLawnView()
}
