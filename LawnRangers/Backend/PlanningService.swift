import Foundation

/// Loads the Planning data (customers + days since mowed) from the Google
/// Sheet via the Apps Script `doGet` endpoint.
enum PlanningService {
    static func fetch() async throws -> [PlanningCustomer] {
        guard let base = BackendConfig.webAppURL else {
            throw NSError(domain: "Planning", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "No backend URL configured (Settings)."])
        }
        var comps = URLComponents(url: base, resolvingAgainstBaseURL: false)
        comps?.queryItems = [URLQueryItem(name: "action", value: "planning")]
        guard let url = comps?.url else { throw URLError(.badURL) }

        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(PlanningResponse.self, from: data)
        if let err = decoded.error, !err.isEmpty {
            throw NSError(domain: "Planning", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: err])
        }
        return decoded.planning
    }
}
