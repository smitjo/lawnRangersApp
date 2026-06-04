import SwiftUI
import SwiftData

/// "Log an Expense" — exact copy of the "Overhead Expense" form.
struct LogExpenseView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var expenses: String = ""
    @State private var amount: String = ""
    @State private var comment: String = ""

    private var canSave: Bool {
        !expenses.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !amount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("This is to record any overhead purchases.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section {
                    TextField("Your answer", text: $expenses)
                } header: {
                    requiredHeader("Expenses")
                }

                Section {
                    TextField("Your answer", text: $amount)
                        .keyboardType(.decimalPad)
                } header: {
                    requiredHeader("Amount")
                }

                Section {
                    TextField("Your answer", text: $comment, axis: .vertical)
                        .lineLimit(2...5)
                } header: {
                    Text("Comment")
                }
            }
            .navigationTitle("Log an Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") { save() }
                        .disabled(!canSave)
                }
            }
        }
    }

    private func requiredHeader(_ title: String) -> some View {
        HStack(spacing: 4) {
            Text(title)
            Text("*").foregroundStyle(.red)
        }
    }

    private func save() {
        let expense = Expense(
            expenses: expenses.trimmingCharacters(in: .whitespacesAndNewlines),
            amount: amount.trimmingCharacters(in: .whitespacesAndNewlines),
            comment: comment.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        let payload = expense.sheetPayload()
        Task { await SheetSubmitter.submit(payload) }
        dismiss()
    }
}

#Preview {
    LogExpenseView()
        .modelContainer(for: [LawnLog.self, Expense.self], inMemory: true)
}
