import SwiftUI
import SwiftData

/// Planning tab — each customer, how many days since their lawn was mowed
/// (computed from logged lawns), and how often it should be mowed. Color-coded
/// green → red by how overdue they are. Data comes live from the "Planning" sheet.
struct PlanningView: View {
    @State private var customers: [PlanningCustomer] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    /// Bumped to tell the weather strip to reload (from the top reload button).
    @State private var weatherRefreshTick = 0

    @Environment(\.modelContext) private var context
    @Query(sort: \PlannedJob.scheduledDate) private var planned: [PlannedJob]
    @State private var editingPlan: PlannedJob?

    /// Most overdue first (never-mowed customers sink to the bottom).
    private var sorted: [PlanningCustomer] {
        customers.sorted { ($0.daysSinceMowed ?? -1) > ($1.daysSinceMowed ?? -1) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                WeatherForecastView(refreshTick: weatherRefreshTick)
                content
            }
                .navigationTitle("Planning")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            weatherRefreshTick += 1   // reload the forecast too
                            Task { await load() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(isLoading)
                    }
                }
                .task { if customers.isEmpty { await load() } }
                .sheet(item: $editingPlan) { PlanJobEditor(job: $0) }
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && customers.isEmpty {
            ProgressView("Loading…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage, customers.isEmpty {
            ContentUnavailableView {
                Label("Couldn’t load", systemImage: "wifi.exclamationmark")
            } description: {
                Text(errorMessage)
            } actions: {
                Button("Try Again") { Task { await load() } }
            }
        } else if customers.isEmpty {
            ContentUnavailableView(
                "No customers",
                systemImage: "person.2.slash",
                description: Text("Add customers to the ‘Planning’ tab of the sheet.")
            )
        } else {
            List {
                if !planned.isEmpty {
                    Section("Planned") {
                        ForEach(planned) { job in
                            Button { editingPlan = job } label: { plannedRow(job) }
                                .buttonStyle(.plain)
                        }
                        .onDelete(perform: deletePlanned)
                    }
                }
                Section("Customers") {
                    ForEach(sorted) { row($0) }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    // MARK: - Planned jobs

    private func plannedRow(_ job: PlannedJob) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar")
                .foregroundStyle(Color.lawnGreen)
            VStack(alignment: .leading, spacing: 2) {
                Text(job.customer).font(.headline)
                Text(job.scheduledDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption).foregroundStyle(.secondary)
                if !job.notes.isEmpty {
                    Text(job.notes).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            Image(systemName: "slider.horizontal.3").font(.caption).foregroundStyle(.tertiary)
        }
    }

    private func addToPlan(_ c: PlanningCustomer) {
        context.insert(PlannedJob(customer: c.customer))
    }

    private func deletePlanned(_ offsets: IndexSet) {
        for i in offsets { context.delete(planned[i]) }
    }

    private func row(_ c: PlanningCustomer) -> some View {
        HStack(spacing: 14) {
            daysBadge(c)
            VStack(alignment: .leading, spacing: 3) {
                Text(c.customer).font(.headline)
                if let interval = c.interval {
                    Text("Mow every \(Int(interval)) days")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                HStack(spacing: 6) {
                    Text(dueText(c))
                    if let last = c.lastMowed, !last.isEmpty {
                        Text("• last \(last)")
                    }
                }
                .font(.caption)
                .foregroundStyle(dueColor(c))
            }
            Spacer(minLength: 0)
            Button { addToPlan(c) } label: {
                Image(systemName: "calendar.badge.plus")
                    .font(.title3)
                    .foregroundStyle(Color.lawnGreen)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Add \(c.customer) to plan")
        }
        .padding(.vertical, 4)
    }

    private func daysBadge(_ c: PlanningCustomer) -> some View {
        VStack(spacing: 0) {
            if let days = c.daysSinceMowed {
                // Days since the customer's MOST RECENT mow (sheet uses MAXIFS).
                Text("\(Int(days))").font(.title3.bold())
                Text("days").font(.system(size: 9))
            } else {
                // Never mowed yet — flips to the day count after the first mow.
                Text("N/A").font(.headline.bold())
            }
        }
        .frame(width: 54, height: 54)
        .background(overdueColor(days: c.daysSinceMowed, interval: c.interval))
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func dueText(_ c: PlanningCustomer) -> String {
        guard c.daysSinceMowed != nil, let due = c.dueIn else { return "Not mowed yet" }
        if due < 0 { return "Overdue by \(-Int(due)) d" }
        if due == 0 { return "Due today" }
        return "Due in \(Int(due)) d"
    }

    private func dueColor(_ c: PlanningCustomer) -> Color {
        guard c.daysSinceMowed != nil, let due = c.dueIn else { return .secondary }
        return due <= 0 ? Color(red: 0.80, green: 0.20, blue: 0.15) : .secondary
    }

    /// Green when freshly mowed, ramping to red once past the mowing interval.
    private func overdueColor(days: Double?, interval: Double?) -> Color {
        guard let d = days else { return .gray }
        let i = interval ?? 14
        let ratio = i > 0 ? d / i : 0
        switch ratio {
        case ..<0.5:  return Color(red: 0.20, green: 0.65, blue: 0.25) // green
        case ..<0.85: return Color(red: 0.55, green: 0.70, blue: 0.20) // yellow-green
        case ..<1.0:  return Color(red: 0.85, green: 0.70, blue: 0.10) // amber
        case ..<1.5:  return Color(red: 0.90, green: 0.50, blue: 0.10) // orange
        default:      return Color(red: 0.80, green: 0.20, blue: 0.15) // red
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            customers = try await PlanningService.fetch()
        } catch {
            errorMessage = error.localizedDescription
            ErrorLogger.log(error.localizedDescription, context: "Planning load")
        }
        isLoading = false
    }
}

#Preview {
    PlanningView()
        .modelContainer(for: [LawnLog.self, Expense.self, PlannedJob.self], inMemory: true)
}
