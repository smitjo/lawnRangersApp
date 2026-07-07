import SwiftUI
import SwiftData

struct HomeView: View {
    @State private var lawns: [SheetLawn] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var showingLogLawn = false
    @State private var showingLogExpense = false
    @State private var showingAddCustomer = false
    @State private var showingSettings = false
    /// When true, the list shows every lawn instead of the limited recent view.
    @State private var showAll = false
    /// The lawn being edited (set by tapping a row).
    @State private var editingLawn: SheetLawn?
    @State private var filter = LawnFilter()
    @State private var showingFilter = false

    @ObservedObject private var plan = PlanStore.shared
    /// A planned job the user tapped to log now.
    @State private var planningToLog: PlannedItem?
    @State private var plannedExpanded = false

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
                        Button { showingFilter = true } label: {
                            Image(systemName: filter.isActive
                                  ? "line.3.horizontal.decrease.circle.fill"
                                  : "line.3.horizontal.decrease.circle")
                                .accessibilityLabel("Filter")
                        }
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
                .sheet(isPresented: $showingLogLawn) { LogLawnView(knownCustomers: customerNames) }
                .sheet(isPresented: $showingLogExpense) { LogExpenseView() }
                .sheet(isPresented: $showingAddCustomer) { AddCustomerView() }
                .sheet(item: $planningToLog, onDismiss: {
                    Task {
                        try? await Task.sleep(for: .seconds(0.4))
                        await load()
                    }
                }) { job in
                    LogLawnView(knownCustomers: customerNames,
                                initialCustomer: job.customer,
                                onComplete: { Task { await plan.remove(id: job.id) } })
                }
                .sheet(item: $editingLawn, onDismiss: {
                    // Give the edit a moment to record, then refresh.
                    Task {
                        try? await Task.sleep(for: .seconds(0.4))
                        await load()
                    }
                }) { LogLawnView(editingLawn: $0, knownCustomers: customerNames) }
                .sheet(isPresented: $showingFilter) {
                    FilterLawnsView(filter: $filter, customers: customerNames)
                }
                .sheet(isPresented: $showingSettings) { SettingsView() }
                .task {
                    if lawns.isEmpty { await load() }
                    await plan.loadIfNeeded()
                }
                .refreshable {
                    await load()
                    await plan.load()
                }
                .onChange(of: showingLogLawn) { _, isShowing in
                    // A form was just dismissed — give the sheet a moment to record, then refresh.
                    if !isShowing {
                        Task {
                            try? await Task.sleep(for: .seconds(0.4))
                            await load()
                        }
                    }
                }
                .onChange(of: showingLogExpense) { _, isShowing in
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
        if isLoading && lawns.isEmpty && plan.items.isEmpty {
            ProgressView("Loading…").frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage, lawns.isEmpty && plan.items.isEmpty {
            ContentUnavailableView {
                Label("Couldn’t load", systemImage: "wifi.exclamationmark")
            } description: {
                Text(errorMessage)
            } actions: {
                Button("Try Again") { Task { await load() } }
            }
        } else if lawns.isEmpty && plan.items.isEmpty {
            ContentUnavailableView {
                Label("No lawns yet", systemImage: "tray")
            } description: {
                Text("Tap the + button in the top-right to log a lawn.")
            }
        } else {
            lawnList
        }
    }

    /// Lawns ordered newest→oldest by their raw timestamp, independent of the
    /// order the rows happen to be stored in the sheet — so any filter or sort
    /// applied on the Google Sheet never changes the app's ordering.
    private var sortedLawns: [SheetLawn] {
        lawns.sorted { ($0.ts ?? 0) > ($1.ts ?? 0) }
    }

    /// True when the last 24 hours has more than 5 lawns, so the whole day is
    /// shown instead of just the last 5.
    private var isShowingFullDay: Bool {
        let cutoff = Date().timeIntervalSince1970 * 1000 - 86_400_000  // 24h ago, epoch ms
        return sortedLawns.filter { ($0.ts ?? 0) >= cutoff }.count > 5
    }

    /// What the Lawns tab shows: the 5 most recent lawns (whenever they were) —
    /// unless the last 24 hours holds more than 5, in which case that whole day's
    /// lawns are shown. Driven entirely by the in-app timestamp, so it stays
    /// independent of any filter/sort applied on the sheet.
    private var displayedLawns: [SheetLawn] {
        let cutoff = Date().timeIntervalSince1970 * 1000 - 86_400_000  // 24h ago, epoch ms
        let dayLawns = sortedLawns.filter { ($0.ts ?? 0) >= cutoff }
        return dayLawns.count > 5 ? dayLawns : Array(sortedLawns.prefix(5))
    }

    /// Unique customer names present in the data, for the filter picker.
    private var customerNames: [String] {
        Array(Set(lawns.compactMap { $0.whereLocation }.filter { !$0.isEmpty })).sorted()
    }

    /// The lawns actually shown. When a filter is active it applies across *all*
    /// lawns; otherwise it's every lawn ("See all") or the limited recent view.
    private var visibleLawns: [SheetLawn] {
        if filter.isActive { return sortedLawns.filter(filter.matches) }
        return showAll ? sortedLawns : displayedLawns
    }

    private var footerText: String {
        if filter.isActive {
            let n = visibleLawns.count
            return "Showing \(n) filtered lawn\(n == 1 ? "" : "s")."
        }
        if showAll { return "Showing all \(sortedLawns.count) lawns." }
        if isShowingFullDay { return "Showing the last 24 hours (\(displayedLawns.count) lawns)." }
        return "Showing the \(displayedLawns.count) most recent lawns."
    }

    private func plannedRow(_ job: PlannedItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .foregroundStyle(Color.lawnGreen)
            VStack(alignment: .leading, spacing: 2) {
                Text(job.customer).font(.headline)
                Text(job.scheduledDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "square.and.pencil")
                .font(.caption).foregroundStyle(.tertiary)
        }
    }

    private var lawnList: some View {
        List {
            if !plan.items.isEmpty {
                Section {
                    DisclosureGroup(isExpanded: $plannedExpanded) {
                        ForEach(plan.sorted) { job in
                            Button { planningToLog = job } label: { plannedRow(job) }
                                .buttonStyle(.plain)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "calendar.badge.clock").foregroundStyle(Color.lawnGreen)
                            Text("Planned").font(.headline)
                            Spacer()
                            Text("\(plan.items.count)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Section {
                if visibleLawns.isEmpty {
                    Text(filter.isActive ? "No lawns match your filters." : "No lawns logged yet.")
                        .foregroundStyle(.secondary)
                }
                ForEach(visibleLawns) { log in
                    Button { editingLawn = log } label: {
                        HStack(alignment: .top, spacing: 8) {
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
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            } footer: {
                HStack {
                    Text(footerText)
                    Spacer()
                    if filter.isActive {
                        Button("Clear") { filter = LawnFilter() }
                            .font(.footnote.weight(.semibold))
                            .textCase(nil)
                    } else {
                        Button(showAll ? "Show less" : "See all") {
                            withAnimation { showAll.toggle() }
                        }
                        .font(.footnote.weight(.semibold))
                        .textCase(nil)
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
        } catch {
            errorMessage = error.localizedDescription
            ErrorLogger.log(error.localizedDescription, context: "Lawns load")
        }
        isLoading = false
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [LawnLog.self, Expense.self, PlannedJob.self], inMemory: true)
}
