import SwiftUI

/// Filter options for the Lawns list. Edits a bound `LawnFilter`; the list
/// applies it across all lawns.
struct FilterLawnsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var filter: LawnFilter
    /// Customer names found in the data, for the picker.
    let customers: [String]

    private let teamMembers = ["Grantham", "Gresham", "Caleb", "Oliver"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Customer") {
                    Picker("Customer", selection: customerBinding) {
                        Text("All").tag("")
                        ForEach(customers, id: \.self) { Text($0).tag($0) }
                    }
                }

                Section("Customer paid?") {
                    Picker("Customer paid?", selection: $filter.customerPaid) {
                        ForEach(LawnFilter.Paid.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Teammember paid?") {
                    Picker("Teammember paid?", selection: $filter.teammemberPaid) {
                        ForEach(LawnFilter.Paid.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Team member") {
                    Picker("Team member", selection: teamBinding) {
                        Text("Anyone").tag("")
                        ForEach(teamMembers, id: \.self) { Text($0).tag($0) }
                    }
                }

                Section("Date range") {
                    Toggle("From date", isOn: fromEnabled)
                    if filter.fromDate != nil {
                        DatePicker("From", selection: fromBinding, displayedComponents: .date)
                    }
                    Toggle("To date", isOn: toEnabled)
                    if filter.toDate != nil {
                        DatePicker("To", selection: toBinding, displayedComponents: .date)
                    }
                }

                if filter.isActive {
                    Section {
                        Button("Clear all filters", role: .destructive) {
                            filter = LawnFilter()
                        }
                    }
                }
            }
            .navigationTitle("Filter Lawns")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // Map nil <-> "" so the pickers can show an "All"/"Anyone" option.
    private var customerBinding: Binding<String> {
        Binding(get: { filter.customer ?? "" },
                set: { filter.customer = $0.isEmpty ? nil : $0 })
    }

    private var teamBinding: Binding<String> {
        Binding(get: { filter.teamMember ?? "" },
                set: { filter.teamMember = $0.isEmpty ? nil : $0 })
    }

    private var fromEnabled: Binding<Bool> {
        Binding(get: { filter.fromDate != nil },
                set: { filter.fromDate = $0 ? (filter.fromDate ?? Date()) : nil })
    }
    private var fromBinding: Binding<Date> {
        Binding(get: { filter.fromDate ?? Date() },
                set: { filter.fromDate = $0 })
    }

    private var toEnabled: Binding<Bool> {
        Binding(get: { filter.toDate != nil },
                set: { filter.toDate = $0 ? (filter.toDate ?? Date()) : nil })
    }
    private var toBinding: Binding<Date> {
        Binding(get: { filter.toDate ?? Date() },
                set: { filter.toDate = $0 })
    }
}
