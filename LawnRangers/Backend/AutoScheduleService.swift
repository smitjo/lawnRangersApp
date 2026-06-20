import Foundation

/// Fetches Tue/Thu auto-schedule recommendations computed **server-side** in the
/// Google Apps Script backend (`?action=autoschedule`).
///
/// This is the backend half of the auto-scheduler; the on-device equivalent is
/// `MowingSchedule`. Both produce the same Tuesday/Thursday-only dates — this one
/// keeps the rule in the shared sheet, the other works instantly and offline.
enum AutoScheduleService {
    static func fetch() async throws -> [AutoScheduleRecommendation] {
        guard let base = BackendConfig.webAppURL else {
            throw NSError(domain: "AutoSchedule", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "No backend URL configured (Settings)."])
        }
        var comps = URLComponents(url: base, resolvingAgainstBaseURL: false)
        comps?.queryItems = [URLQueryItem(name: "action", value: "autoschedule")]
        guard let url = comps?.url else { throw URLError(.badURL) }

        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(AutoScheduleResponse.self, from: data)
        if let err = decoded.error, !err.isEmpty {
            throw NSError(domain: "AutoSchedule", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: err])
        }
        return decoded.autoschedule
    }
}
