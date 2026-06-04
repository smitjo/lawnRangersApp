import Foundation

/// Loads the current Lawn Log + Overhead Expense rows from the sheet so the
/// Home screen mirrors the sheet (reflecting both additions and deletions).
enum EntriesService {
    static func fetch() async throws -> EntriesResponse {
        guard let base = BackendConfig.webAppURL else {
            throw NSError(domain: "Entries", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "No backend URL configured (Settings)."])
        }
        var comps = URLComponents(url: base, resolvingAgainstBaseURL: false)
        comps?.queryItems = [URLQueryItem(name: "action", value: "entries")]
        guard let url = comps?.url else { throw URLError(.badURL) }

        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(EntriesResponse.self, from: data)
        if let err = decoded.error, !err.isEmpty {
            throw NSError(domain: "Entries", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: err])
        }
        return decoded
    }
}
