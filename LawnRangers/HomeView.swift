import SwiftUI
import SwiftData

struct HomeView: View {
    @Query(sort: \LawnLog.timestamp, order: .reverse) private var lawnLogs: [LawnLog]
    @Query(sort: \Expense.timestamp, order: .reverse) private var expenses: [Expense]

    @State private var activeSheet: ActiveSheet?
    @State private var showingSettings = false

    /// The two entry types reachable from the "+" dropdown in the top-right.
    private enum ActiveSheet: Identifiable {
        case logLawn
        case logExpense
        var id: Int { hashValue }
    }

    var body: some View {
        NavigationStack {
            Group {
                if lawnLogs.isEmpty && expenses.isEmpty {
                    emptyState
                } else {
                    activityList
                }
            }
            .navigationTitle("Lawn Rangers")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .accessibilityLabel("Settings")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    // The "+" dropdown menu.
                    Menu {
                        Button {
                            activeSheet = .logLawn
                        } label: {
                            Label("Log a Lawn", systemImage: "leaf")
                        }
                        Button {
                            activeSheet = .logExpense
                        } label: {
                            Label("Log an Expense", systemImage: "dollarsign.circle")
                        }
                    } label: {
                        Image(systemName: "plus")
                            .accessibilityLabel("Add entry")
                    }
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .logLawn:
                    LogLawnView()
                case .logExpense:
                    LogExpenseView()
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No entries yet", systemImage: "tray")
        } description: {
            Text("Tap the + button in the top-right to log a lawn or an expense.")
        }
    }

    // MARK: - Activity list

    private var activityList: some View {
        List {
            if !lawnLogs.isEmpty {
                Section("Lawns") {
                    ForEach(lawnLogs) { log in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(log.whereLocation.isEmpty ? "Lawn" : log.whereLocation)
                                .font(.headline)
                            HStack {
                                Text(log.timestamp, style: .date)
                                Spacer()
                                Text(log.howMuch)
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            HStack(spacing: 12) {
                                Label("Customer: \(log.customerPaid)", systemImage: "person")
                                Label("Team: \(log.teammemberPaid)", systemImage: "person.2")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            if !expenses.isEmpty {
                Section("Expenses") {
                    ForEach(expenses) { expense in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(expense.expenses.isEmpty ? "Expense" : expense.expenses)
                                .font(.headline)
                            HStack {
                                Text(expense.timestamp, style: .date)
                                Spacer()
                                Text(expense.amount)
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [LawnLog.self, Expense.self], inMemory: true)
}
