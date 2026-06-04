import SwiftUI
import SwiftData

/// "Log a Lawn" — exact copy of the "Lawn Mowing Wizard - 2025 Daily Log" form.
struct LogLawnView: View {
    @Environment(\.dismiss) private var dismiss

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

    private let teamMembers = ["Grantham", "Gresham", "Caleb", "Oliver"]

    /// Seed customers ∪ previously entered locations, sorted & de-duplicated.
    private var allCustomers: [String] {
        let used = pastLogs.map(\.whereLocation).filter { !$0.isEmpty }
        return Array(Set(CustomerDirectory.seed + used)).sorted()
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
            .navigationTitle("Log a Lawn")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") { save() }
                        .disabled(!canSave || isSubmitting)
                }
            }
        }
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
        let log = LawnLog(
            whereLocation: resolvedWhere,
            who: resolvedTeam,
            howMuch: resolvedHowMuch,
            customerPaid: customerPaid,
            teammemberPaid: teammemberPaid,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        let payload = log.sheetPayload()
        Task { await SheetSubmitter.submit(payload) }
        dismiss()
    }
}

#Preview {
    LogLawnView()
        .modelContainer(for: [LawnLog.self, Expense.self], inMemory: true)
}
