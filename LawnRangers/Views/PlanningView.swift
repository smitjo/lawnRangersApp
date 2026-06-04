import SwiftUI

/// Planning tab — each customer and how many days since their lawn was mowed,
/// color-coded green → red by how overdue they are (days vs. mowing interval).
/// Data comes live from the "Lawns due, 2025" sheet.
struct PlanningView: View {
    @State private var customers: [PlanningCustomer] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    /// Most overdue first.
    private var sorted: [PlanningCustomer] {
        customers.sorted { ($0.daysSinceMowed ?? -1) > ($1.daysSinceMowed ?? -1) }
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Planning")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            Task { await load() }
                        } label: {
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
                description: Text("No rows found on the ‘Lawns due, 2025’ sheet.")
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
                if let address = c.address, !address.isEmpty {
                    Text(address).font(.subheadline).foregroundStyle(.secondary)
                }
                HStack(spacing: 6) {
                    if let loop = c.loop, !loop.isEmpty { Text(loop) }
                    if let interval = c.interval { Text("• every \(Int(interval))d") }
                    if let price = c.price, !price.isEmpty { Text("• \(price)") }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                HStack(spacing: 14) {
                    if let next = c.nextDate, !next.isEmpty {
                        Label(next, systemImage: "calendar")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    if let phone = c.phone, !phone.isEmpty, let url = telURL(phone) {
                        Link(destination: url) {
                            Label(phone, systemImage: "phone.fill").font(.caption2)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    private func daysBadge(_ c: PlanningCustomer) -> some View {
        let days = c.daysSinceMowed
        let text: String = {
            guard let d = days, d <= 900 else { return "—" }
            return "\(Int(d))"
        }()
        return VStack(spacing: 0) {
            Text(text).font(.title3.bold())
            Text("days").font(.system(size: 9))
        }
        .frame(width: 54, height: 54)
        .background(overdueColor(days: days, interval: c.interval))
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    /// Green when freshly mowed, ramping to red once past the mowing interval.
    private func overdueColor(days: Double?, interval: Double?) -> Color {
        guard let d = days, d <= 900 else { return .gray }
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

    private func telURL(_ phone: String) -> URL? {
        let digits = phone.filter(\.isNumber)
        guard digits.count >= 7 else { return nil }
        return URL(string: "tel://\(digits.prefix(11))")
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
