import SwiftUI

/// Expenses tab — lists overhead expenses (newest first) read live from the
/// sheet. Shares the same "+" dropdown as the Lawns tab so either kind of entry
/// can be logged from here.
struct ExpensesView: View {
    @State private var expenses: [SheetExpense] = []
    /// Lawns are fetched too, only to feed the Log-a-Lawn customer dropdown.
    @State private var lawns: [SheetLawn] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var showingLogLawn = false
    @State private var showingLogExpense = false
    @State private var showingAddCustomer = false
    @State private var showingSettings = false

    private var customerNames: [String] {
        Array(Set(lawns.compactMap { $0.whereLocation }.filter { !$0.isEmpty })).sorted()
    }

    private var sortedExpenses: [SheetExpense] {
        expenses.sorted { ($0.ts ?? 0) > ($1.ts ?? 0) }
    }

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
                        Menu {
                            Button { showingLogLawn = true } label: {
                                Label("Log a Lawn", systemImage: "leaf")
                            }
                            Button { showingLogExpense = true } label: {
                                Label("Log an Expense", systemImage: "dollarsign.circle")
                            }
                            Button { showingAddCustomer = true } label: {
                                Label("Add a Customer", systemImage: "person.badge.plus")
                            }
                        } label: {
                            Image(systemName: "plus").accessibilityLabel("Add entry")
                        }
                    }
                }
                .sheet(isPresented: $showingLogLawn) { LogLawnView(knownCustomers: customerNames, recentLawns: lawns) }
                .sheet(isPresented: $showingLogExpense) { LogExpenseView() }
                .sheet(isPresented: $showingAddCustomer) { AddCustomerView() }
                .sheet(isPresented: $showingSettings) { SettingsView() }
                .task { if expenses.isEmpty { await load() } }
                .refreshable { await load() }
                .onChange(of: showingLogExpense) { _, isShowing in
                    if !isShowing {
                        Task {
                            try? await Task.sleep(for: .seconds(0.4))
                            await load()
                        }
                    }
                }
                .onChange(of: showingLogLawn) { _, isShowing in
                    if !isShowing {
                        Task {
                            try? await Task.sleep(for: .seconds(0.4))
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
            ForEach(sortedExpenses) { expense in
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
            lawns = result.lawns
        } catch {
            errorMessage = error.localizedDescription
            ErrorLogger.log(error.localizedDescription, context: "Expenses load")
        }
        isLoading = false
    }
}

#Preview {
    ExpensesView()
}
