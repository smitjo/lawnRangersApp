import SwiftUI

/// Adjust a planned job's date, time, and notes — or remove it. Writes through
/// the shared PlanStore to the sheet.
struct PlanJobEditor: View {
    let item: PlannedItem
    @ObservedObject private var plan = PlanStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var date: Date
    @State private var notes: String
    @State private var address: String

    init(item: PlannedItem) {
        self.item = item
        _date = State(initialValue: item.scheduledDate)
        _notes = State(initialValue: item.notes ?? "")
        _address = State(initialValue: item.address ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Customer") {
                    Text(item.customer).font(.headline)
                }
                Section("When") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    DatePicker("Time", selection: $date, displayedComponents: .hourAndMinute)
                }
                Section("Address") {
                    TextField("Street address (for the map route)", text: $address, axis: .vertical)
                        .textContentType(.fullStreetAddress)
                        .lineLimit(1...3)
                }
                Section("Notes") {
                    TextField("Other info (gate code, where to start, etc.)",
                              text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section {
                    Button("Remove from plan", role: .destructive) {
                        dismiss()
                        Task { await plan.remove(id: item.id) }
                    }
                }
            }
            .navigationTitle("Edit Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                        Task { await plan.update(id: item.id, date: date, notes: notes, address: address) }
                    }
                }
            }
        }
    }
}
