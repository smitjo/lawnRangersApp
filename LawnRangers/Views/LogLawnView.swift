import SwiftUI
import SwiftData

/// "Log a Lawn" — exact copy of the "Lawn Mowing Wizard - 2025 Daily Log" form.
struct LogLawnView: View {
    @Environment(\.dismiss) private var dismiss

    /// When set, the form edits this existing entry (found in the sheet by its
    /// timestamp) instead of creating a new one.
    var editingLawn: SheetLawn? = nil
    @State private var didPrefill = false

    /// Customer names from the live sheet data (passed in by the Lawns tab), so
    /// the "Where?" dropdown reflects customers already in use across the team.
    var knownCustomers: [String] = []

    /// Previously entered locations, used to grow the "Where?" dropdown.
    @Query(sort: \LawnLog.timestamp, order: .reverse) private var pastLogs: [LawnLog]

    // Q1 — Where?
    private static let otherTag = "__other__"
    @State private var whereSelection: String = ""      // "" = none chosen yet
    @State private var whereCustom: String = ""

    // Q2 — Who?
    @State private var selectedTeam: Set<String> = []
    @State private var whoOtherEnabled = false
    @State private var whoOther: String = ""

    // Q3 — How much?  Defaults to "Standard"; tap in to type an actual rate.
    @State private var howMuch: String = "Standard"

    // Q4 / Q5 — Paid?
    @State private var customerPaid: String = ""        // "Paid" / "Unpaid"
    @State private var teammemberPaid: String = ""      // "Paid" / "Unpaid"

    // Q6 — Note
    @State private var note: String = ""

    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private let teamMembers = ["Grantham", "Gresham", "Caleb", "Oliver"]

    /// Seed customers ∪ previously entered locations, sorted & de-duplicated.
    private var allCustomers: [String] {
        let used = pastLogs.map(\.whereLocation).filter { !$0.isEmpty }
        return Array(Set(CustomerDirectory.seed + used + knownCustomers)).sorted()
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

    var body: some View {
        NavigationStack {
            Form {
                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.subheadline)
                    }
                }
                // Q1 — Where?
                Section {
                    Picker("Where?", selection: $whereSelection) {
                        Text("Choose").tag("")
                        ForEach(allCustomers, id: \.self) { Text($0).tag($0) }
                        Text("New customer…").tag(Self.otherTag)
                    }
                    if whereSelection == Self.otherTag {
                        TextField("New customer name", text: $whereCustom)
                            .textInputAutocapitalization(.words)
                    }
                } header: {
                    requiredHeader("Where?")
                }

                // Q2 — Who?
                Section {
                    ForEach(teamMembers, id: \.self) { member in
                        checkRow(title: member, isOn: selectedTeam.contains(member)) {
                            toggle(member, in: &selectedTeam)
                        }
                    }
                    checkRow(title: "Other", isOn: whoOtherEnabled) {
                        whoOtherEnabled.toggle()
                    }
                    if whoOtherEnabled {
                        TextField("Other", text: $whoOther)
                            .textInputAutocapitalization(.words)
                    }
                } header: {
                    requiredHeader("Who?")
                }

                // Q3 — How much?  Pre-filled with "Standard"; tap to enter a rate.
                Section {
                    TextField("Standard", text: $howMuch)
                } header: {
                    requiredHeader("How much? Enter 'Standard' or the actual rate.")
                } footer: {
                    Text("Leave as \"Standard\" to use the customer's standard rate, or type the actual amount.")
                }

                // Q4 — Customer paid?
                Section {
                    radioPicker(selection: $customerPaid, options: ["Paid", "Unpaid"])
                } header: {
                    requiredHeader("Customer paid?")
                }

                // Q5 — Teammember paid?
                Section {
                    radioPicker(selection: $teammemberPaid, options: ["Paid", "Unpaid"])
                } header: {
                    requiredHeader("Teammember paid?")
                }

                // Q6 — Note (optional)
                Section {
                    TextField("Your answer", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                } header: {
                    Text("Note. Include Address & Phone for new customers")
                }
            }
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
                            .disabled(!canSave)
                    }
                }
            }
            .onAppear { prefillIfNeeded() }
        }
    }

    // MARK: - Edit prefill

    /// On first appearance in edit mode, populate the form from the entry.
    private func prefillIfNeeded() {
        guard let e = editingLawn, !didPrefill else { return }
        didPrefill = true

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
        howMuch = amount.isEmpty ? "Standard" : amount
        customerPaid = e.customerPaid ?? ""
        teammemberPaid = e.teammemberPaid ?? ""
        note = e.note ?? ""
    }

    // MARK: - Reusable rows

    private func requiredHeader(_ title: String) -> some View {
        HStack(spacing: 4) {
            Text(title)
            Text("*").foregroundStyle(.red)
        }
    }

    private func checkRow(title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .foregroundStyle(isOn ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                Text(title).foregroundStyle(.primary)
                Spacer()
            }
        }
    }

    private func radioPicker(selection: Binding<String>, options: [String]) -> some View {
        ForEach(options, id: \.self) { option in
            Button {
                selection.wrappedValue = option
            } label: {
                HStack {
                    Image(systemName: selection.wrappedValue == option ? "largecircle.fill.circle" : "circle")
                        .foregroundStyle(selection.wrappedValue == option ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    Text(option).foregroundStyle(.primary)
                    Spacer()
                }
            }
        }
    }

    private func toggle(_ value: String, in set: inout Set<String>) {
        if set.contains(value) { set.remove(value) } else { set.insert(value) }
    }

    // MARK: - Save

    private func save() {
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
        .modelContainer(for: [LawnLog.self, Expense.self], inMemory: true)
}
