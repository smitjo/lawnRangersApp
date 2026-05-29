import SwiftUI
import SwiftData

struct HomeView: View {
    @Query(sort: \LawnLog.date, order: .reverse) private var lawnLogs: [LawnLog]
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]

    @State private var activeSheet: ActiveSheet?

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
                            Text(log.customerName.isEmpty ? "Lawn service" : log.customerName)
                                .font(.headline)
                            HStack {
                                Text(log.date, style: .date)
                                if log.amountCharged > 0 {
                                    Spacer()
                                    Text(log.amountCharged, format: .currency(code: "USD"))
                                }
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            if !expenses.isEmpty {
                Section("Expenses") {
                    ForEach(expenses) { expense in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(expense.category.isEmpty ? "Expense" : expense.category)
                                .font(.headline)
                            HStack {
                                Text(expense.date, style: .date)
                                Spacer()
                                Text(expense.amount, format: .currency(code: "USD"))
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
