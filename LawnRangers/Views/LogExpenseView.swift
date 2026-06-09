import SwiftUI
import SwiftData

/// "Log an Expense" — mirrors the "Overhead Expense" form. The look matches the
/// modern Log-a-Lawn card style; the fields and submitted data are unchanged.
struct LogExpenseView: View {
    @Environment(\.dismiss) private var dismiss

    // Q1 — Expense: a quick "100% Gas" option, or "Other" for a typed name.
    @State private var expenseChoice: String = ""   // "" = none, "100% Gas", or "Other"
    @State private var expenseCustom: String = ""
    @State private var amount: String = ""
    @State private var comment: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    /// The expense name to record: "100% Gas", or the typed name when "Other".
    private var resolvedExpense: String {
        expenseChoice == "Other"
            ? expenseCustom.trimmingCharacters(in: .whitespacesAndNewlines)
            : expenseChoice
    }

    private var canSave: Bool {
        !resolvedExpense.isEmpty
            && !amount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let errorMessage {
                        errorBanner(errorMessage)
                    }

                    Text("Record an overhead purchase for the business.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    fieldCard(icon: "cart.fill", title: "Expense", required: true) {
                        HStack(spacing: 10) {
                            choicePill("100% Gas")
                            choicePill("Other")
                        }
                        if expenseChoice == "Other" {
                            inputField {
                                TextField("Expense name", text: $expenseCustom)
                                    .textInputAutocapitalization(.words)
                            }
                        }
                    }

                    fieldCard(icon: "dollarsign.circle.fill", title: "Amount", required: true) {
                        inputField {
                            HStack(spacing: 4) {
                                Text("$").foregroundStyle(.secondary)
                                TextField("0.00", text: $amount)
                                    .keyboardType(.decimalPad)
                            }
                        }
                    }

                    fieldCard(icon: "note.text", title: "Comment", required: false) {
                        inputField {
                            TextField("Optional details", text: $comment, axis: .vertical)
                                .lineLimit(3...6)
                        }
                    }
                }
                .padding(16)
            }
            .background(backdrop)
            .navigationTitle("Log an Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Button("Submit") { save() }
                            .fontWeight(.semibold)
                            .disabled(!canSave)
                    }
                }
            }
        }
    }

    // MARK: - Styled building blocks (mirrors LogLawnView)

    private var backdrop: some View {
        LinearGradient(
            colors: [Color(.systemBackground), Color.lawnGreen.opacity(0.10)],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    }

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

    private func choicePill(_ option: String) -> some View {
        let isOn = expenseChoice == option
        return Button {
            expenseChoice = option
        } label: {
            Text(option)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isOn ? Color.white : Color.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(Capsule().fill(isOn ? Color.lawnGreen : Color.primary.opacity(0.06)))
                .overlay(Capsule().stroke(Color.white.opacity(isOn ? 0 : 0.08), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Save

    private func save() {
        let expense = Expense(
            expenses: resolvedExpense,
            amount: amount.trimmingCharacters(in: .whitespacesAndNewlines),
            comment: comment.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        let payload = expense.sheetPayload()

        // Only dismiss once the save is confirmed; on failure keep the form open.
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
    LogExpenseView()
        .modelContainer(for: [LawnLog.self, Expense.self], inMemory: true)
}
