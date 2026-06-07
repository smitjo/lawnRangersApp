import SwiftUI

/// "Expenses" tab — mirrors the Lawns (Home) tab, but for overhead expenses.
/// Reads the current Overhead Expense rows live from the sheet and lets you log
/// a new expense from the "+" button in the top-right.
struct ExpensesView: View {
    @State private var expenses: [SheetExpense] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var showingLogExpense = false
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Expenses")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { showingSettings = true } label: {
                            Image(systemName: "gearshape").accessibilityLabel("Settings")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { Task { await load() } } label: {
                            Image(systemName: "arrow.clockwise").accessibilityLabel("Refresh")
                        }
                        .disabled(isLoading)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showingLogExpense = true } label: {
                            Image(systemName: "plus").accessibilityLabel("Log an expense")
                        }
                    }
                }
                .sheet(isPresented: $showingLogExpense) { LogExpenseView() }
                .sheet(isPresented: $showingSettings) { SettingsView() }
                .task { if expenses.isEmpty { await load() } }
                .refreshable { await load() }
                .onChange(of: showingLogExpense) { _, isShowing in
                    // A form was just dismissed — give the sheet a moment to record, then refresh.
                    if !isShowing {
                        Task {
                            try? await Task.sleep(for: .seconds(1.2))
                            await load()
                        }
                    }
                }
        }
    }

    // MARK: - Content states

    @ViewBuilder
    private var content: some View {
        if isLoading && expenses.isEmpty {
            ProgressView("Loading…").frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage, expenses.isEmpty {
            ContentUnavailableView {
                Label("Couldn’t load", systemImage: "wifi.exclamationmark")
            } description: {
                Text(errorMessage)
            } actions: {
                Button("Try Again") { Task { await load() } }
            }
        } else if expenses.isEmpty {
            ContentUnavailableView {
                Label("No expenses yet", systemImage: "tray")
            } description: {
                Text("Tap the + button in the top-right to log an expense.")
            }
        } else {
            expenseList
        }
    }

    private var expenseList: some View {
        List {
            ForEach(Array(expenses.reversed().enumerated()), id: \.offset) { _, expense in
                VStack(alignment: .leading, spacing: 4) {
                    Text(expense.expenses?.isEmpty == false ? expense.expenses! : "Expense")
                        .font(.headline)
                    HStack {
                        Text(expense.date ?? "")
                        Spacer()
                        Text(currencyFormatted(expense.amount))
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    if let comment = expense.comment, !comment.isEmpty {
                        Text(comment)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    /// Formats a raw amount string as USD currency (e.g. "50" → "$50.00").
    /// Falls back to the raw text if it isn't numeric.
    private func currencyFormatted(_ raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return "" }
        let cleaned = raw.filter { $0.isNumber || $0 == "." }
        if !cleaned.isEmpty, let value = Double(cleaned) {
            return value.formatted(.currency(code: "USD"))
        }
        return raw
    }

    // MARK: - Load

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let result = try await EntriesService.fetch()
            expenses = result.expenses
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

#Preview {
    ExpensesView()
}
