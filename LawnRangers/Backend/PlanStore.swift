import Foundation

private struct PlanResponse: Decodable {
    let plan: [PlannedItem]
    let error: String?
}

/// The shared planning backlog, stored in the "Plan" tab of the Google Sheet so
/// it's available from any device. A single shared instance is observed by both
/// the Planning and Lawns tabs so they stay in sync. Writes are optimistic
/// (update the in-memory list immediately) and mirrored to the sheet.
@MainActor
final class PlanStore: ObservableObject {
    static let shared = PlanStore()
    private init() {}

    @Published private(set) var items: [PlannedItem] = []
    @Published private(set) var isLoading = false

    /// Soonest-scheduled first.
    var sorted: [PlannedItem] {
        items.sorted { ($0.scheduled ?? 0) < ($1.scheduled ?? 0) }
    }

    func loadIfNeeded() async {
        if items.isEmpty { await load() }
    }

    func load() async {
        guard let url = planURL() else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                throw URLError(.badServerResponse)
            }
            items = try JSONDecoder().decode(PlanResponse.self, from: data).plan
        } catch {
            ErrorLogger.log(error.localizedDescription, context: "Plan load")
        }
    }

    func add(customer: String) async {
        await add(customer: customer, scheduled: Date(), notes: "")
    }

    /// Adds a planned job for a specific date/time (used by auto-scheduling and
    /// voice planning). Optimistic, then mirrored to the sheet.
    func add(customer: String, scheduled: Date, notes: String) async {
        let id = UUID().uuidString
        // Optimistic: show it right away.
        items.append(PlannedItem(id: id, customer: customer,
                                 scheduled: scheduled.timeIntervalSince1970 * 1000,
                                 notes: notes, address: ""))
        await SheetSubmitter.submit([
            "type": "planAdd",
            "id": id,
            "customer": customer,
            "scheduled": ISO8601DateFormatter().string(from: scheduled),
            "notes": notes,
        ])
        await load()
    }

    /// True if the customer already has a planned job (case-insensitive), so
    /// auto-scheduling doesn't create duplicates.
    func isPlanned(_ customer: String) -> Bool {
        let key = customer.trimmingCharacters(in: .whitespaces).lowercased()
        return items.contains { $0.customer.trimmingCharacters(in: .whitespaces).lowercased() == key }
    }

    func update(id: String, date: Date, notes: String, address: String) async {
        await SheetSubmitter.submit([
            "type": "planUpdate",
            "id": id,
            "scheduled": ISO8601DateFormatter().string(from: date),
            "notes": notes,
            "address": address,
        ])
        await load()
    }

    func remove(id: String) async {
        items.removeAll { $0.id == id }   // optimistic
        await SheetSubmitter.submit(["type": "planDelete", "id": id])
    }

    private func planURL() -> URL? {
        guard let base = BackendConfig.webAppURL else { return nil }
        var comps = URLComponents(url: base, resolvingAgainstBaseURL: false)
        comps?.queryItems = [URLQueryItem(name: "action", value: "plan")]
        return comps?.url
    }
}
