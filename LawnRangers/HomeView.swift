import SwiftUI

struct HomeView: View {
    @State private var lawns: [SheetLawn] = []
    @State private var expenses: [SheetExpense] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var activeSheet: ActiveSheet?
    @State private var showingSettings = false

    /// The two entry types reachable from the "+" dropdown in the top-right.
    private enum ActiveSheet: Identifiable, Equatable {
        case logLawn
        case logExpense
        var id: Int { hashValue }
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Lawn Rangers")
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
                            Button { activeSheet = .logLawn } label: {
                                Label("Log a Lawn", systemImage: "leaf")
                            }
                            Button { activeSheet = .logExpense } label: {
                                Label("Log an Expense", systemImage: "dollarsign.circle")
                            }
                        } label: {
                            Image(systemName: "plus").accessibilityLabel("Add entry")
                        }
                    }
                }
                .sheet(item: $activeSheet) { sheet in
                    switch sheet {
                    case .logLawn: LogLawnView()
                    case .logExpense: LogExpenseView()
                    }
                }
                .sheet(isPresented: $showingSettings) { SettingsView() }
                .task { if lawns.isEmpty && expenses.isEmpty { await load() } }
                .refreshable { await load() }
                .onChange(of: activeSheet) { _, newValue in
                    // A form was just dismissed — give the sheet a moment to record, then refresh.
                    if newValue == nil {
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
        if isLoading && lawns.isEmpty && expenses.isEmpty {
            ProgressView("Loading…").frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage, lawns.isEmpty && expenses.isEmpty {
            ContentUnavailableView {
                Label("Couldn’t load", systemImage: "wifi.exclamationmark")
            } description: {
                Text(errorMessage)
            } actions: {
                Button("Try Again") { Task { await load() } }
            }
        } else if lawns.isEmpty && expenses.isEmpty {
            ContentUnavailableView {
                Label("No entries yet", systemImage: "tray")
            } description: {
                Text("Tap the + button in the top-right to log a lawn or an expense.")
            }
        } else {
            activityList
        }
    }

    private var activityList: some View {
        List {
            if !lawns.isEmpty {
                Section("Lawns") {
                    ForEach(Array(lawns.reversed().enumerated()), id: \.offset) { _, log in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(log.whereLocation?.isEmpty == false ? log.whereLocation! : "Lawn")
                                .font(.headline)
                            HStack {
                                Text(log.date ?? "")
                                Spacer()
                                Text(log.howMuch ?? "")
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            HStack(spacing: 12) {
                                Label("Customer: \(log.customerPaid ?? "")", systemImage: "person")
                                Label("Team: \(log.teammemberPaid ?? "")", systemImage: "person.2")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            if !expenses.isEmpty {
                Section("Expenses") {
                    ForEach(Array(expenses.reversed().enumerated()), id: \.offset) { _, expense in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(expense.expenses?.isEmpty == false ? expense.expenses! : "Expense")
                                .font(.headline)
                            HStack {
                                Text(expense.date ?? "")
                                Spacer()
                                Text(expense.amount ?? "")
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Load

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let result = try await EntriesService.fetch()
            lawns = result.lawns
            expenses = result.expenses
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

#Preview {
    HomeView()
}
