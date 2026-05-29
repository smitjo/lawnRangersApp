import SwiftUI
import SwiftData

/// "Log a Lawn" form.
///
/// PLACEHOLDER FIELDS: these mirror a typical lawn-care service log. Replace
/// them with the exact questions from the source Google Form once available.
struct LogLawnView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var date: Date = .now
    @State private var customerName: String = ""
    @State private var address: String = ""
    @State private var crewMember: String = ""
    @State private var selectedServices: Set<String> = []
    @State private var amountCharged: Double?
    @State private var paymentMethod: String = "Cash"
    @State private var notes: String = ""

    private let serviceOptions = [
        "Mow", "Edge", "Trim / Weed-eat", "Blow / Cleanup",
        "Fertilize", "Weed control", "Hedge trimming", "Leaf removal", "Other",
    ]
    private let paymentOptions = ["Cash", "Check", "Venmo", "Card", "Invoice"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Service") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    TextField("Customer name", text: $customerName)
                    TextField("Property address", text: $address, axis: .vertical)
                    TextField("Crew member", text: $crewMember)
                }

                Section("Services performed") {
                    ForEach(serviceOptions, id: \.self) { option in
                        Button {
                            toggle(option)
                        } label: {
                            HStack {
                                Text(option)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedServices.contains(option) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                    }
                }

                Section("Billing") {
                    TextField("Amount charged", value: $amountCharged, format: .currency(code: "USD"))
                        .keyboardType(.decimalPad)
                    Picker("Payment method", selection: $paymentMethod) {
                        ForEach(paymentOptions, id: \.self) { Text($0) }
                    }
                }

                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Log a Lawn")
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

    private func toggle(_ option: String) {
        if selectedServices.contains(option) {
            selectedServices.remove(option)
        } else {
            selectedServices.insert(option)
        }
    }

    private func save() {
        let log = LawnLog(
            date: date,
            customerName: customerName,
            address: address,
            crewMember: crewMember,
            services: serviceOptions.filter { selectedServices.contains($0) },
            amountCharged: amountCharged ?? 0,
            paymentMethod: paymentMethod,
            notes: notes
        )
        context.insert(log)
        dismiss()
    }
}

#Preview {
    LogLawnView()
        .modelContainer(for: [LawnLog.self, Expense.self], inMemory: true)
}
