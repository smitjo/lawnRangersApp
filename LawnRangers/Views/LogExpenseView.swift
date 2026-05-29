import SwiftUI
import SwiftData

/// "Log an Expense" form.
///
/// PLACEHOLDER FIELDS: these mirror a typical business expense log. Replace
/// them with the exact questions from the source Google Form once available.
struct LogExpenseView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var date: Date = .now
    @State private var category: String = "Fuel"
    @State private var vendor: String = ""
    @State private var amount: Double?
    @State private var paymentMethod: String = "Card"
    @State private var notes: String = ""

    private let categoryOptions = [
        "Fuel", "Equipment", "Equipment repair", "Supplies",
        "Labor / Payroll", "Insurance", "Vehicle", "Marketing", "Other",
    ]
    private let paymentOptions = ["Cash", "Check", "Card", "Venmo"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Expense") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    Picker("Category", selection: $category) {
                        ForEach(categoryOptions, id: \.self) { Text($0) }
                    }
                    TextField("Vendor / paid to", text: $vendor)
                }

                Section("Amount") {
                    TextField("Amount", value: $amount, format: .currency(code: "USD"))
                        .keyboardType(.decimalPad)
                    Picker("Payment method", selection: $paymentMethod) {
                        ForEach(paymentOptions, id: \.self) { Text($0) }
                    }
                }

                Section("Notes") {
                    TextField("Description / notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Log an Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
        }
    }

    private func save() {
        let expense = Expense(
            date: date,
            category: category,
            vendor: vendor,
            amount: amount ?? 0,
            paymentMethod: paymentMethod,
            notes: notes
        )
        context.insert(expense)
        dismiss()
    }
}

#Preview {
    LogExpenseView()
        .modelContainer(for: [LawnLog.self, Expense.self], inMemory: true)
}
