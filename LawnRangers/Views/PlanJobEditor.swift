import SwiftUI
import SwiftData

/// Adjust a planned job's date, time, and notes — or remove it from the plan.
/// Edits a SwiftData object directly via @Bindable, so changes auto-save.
struct PlanJobEditor: View {
    @Bindable var job: PlannedJob
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    var body: some View {
        NavigationStack {
            Form {
                Section("Customer") {
                    Text(job.customer).font(.headline)
                }
                Section("When") {
                    DatePicker("Date", selection: $job.scheduledDate, displayedComponents: .date)
                    DatePicker("Time", selection: $job.scheduledDate, displayedComponents: .hourAndMinute)
                }
                Section("Notes") {
                    TextField("Other info (gate code, where to start, etc.)",
                              text: $job.notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section {
                    Button("Remove from plan", role: .destructive) {
                        context.delete(job)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Edit Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
