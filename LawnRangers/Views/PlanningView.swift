import SwiftUI

/// Planning tab — each customer, how many days since their lawn was mowed
/// (computed from logged lawns), and how often it should be mowed. Color-coded
/// green → red by how overdue they are. Data comes live from the "Planning" sheet.
struct PlanningView: View {
    @State private var customers: [PlanningCustomer] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    /// Most overdue first (never-mowed customers sink to the bottom).
    private var sorted: [PlanningCustomer] {
        customers.sorted { ($0.daysSinceMowed ?? -1) > ($1.daysSinceMowed ?? -1) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                WeatherForecastView()
                content
            }
                .navigationTitle("Planning")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { Task { await load() } } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(isLoading)
                    }
                }
                .task { if customers.isEmpty { await load() } }
                .refreshable { await load() }
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
            List(sorted) { row($0) }
                .listStyle(.plain)
        }
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
        }
        .padding(.vertical, 4)
    }

    private func daysBadge(_ c: PlanningCustomer) -> some View {
        let text = c.daysSinceMowed.map { "\(Int($0))" } ?? "—"
        return VStack(spacing: 0) {
            Text(text).font(.title3.bold())
            Text("days").font(.system(size: 9))
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
        }
        isLoading = false
    }
}

#Preview {
    PlanningView()
}
