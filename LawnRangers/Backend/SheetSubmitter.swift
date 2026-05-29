import Foundation

/// Best-effort submission of an entry to the Google Sheets backend.
///
/// Entries are always saved locally first; this posts a copy to the configured
/// Apps Script Web App. If no endpoint is configured (or the request fails),
/// it returns quietly — the local copy is the source of truth and could later
/// be re-synced.
enum SheetSubmitter {
    enum SubmitResult {
        case notConfigured
        case success
        case failure(Error)
    }

    @discardableResult
    static func submit(_ payload: [String: Any]) async -> SubmitResult {
        guard let url = BackendConfig.webAppURL else { return .notConfigured }

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)

            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                return .failure(URLError(.badServerResponse))
            }
            return .success
        } catch {
            return .failure(error)
        }
    }
}
