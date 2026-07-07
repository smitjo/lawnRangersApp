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

            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                ErrorLogger.log("HTTP \(http.statusCode) submitting \(payload["type"] as? String ?? "entry")",
                                context: "SheetSubmitter")
                return .failure(URLError(.badServerResponse))
            }
            // Apps Script reports failures as HTTP 200 with {result:"error"} in
            // the body — surface those instead of calling them a success.
            if let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let result = body["result"] as? String, result == "error" {
                let message = (body["error"] as? String) ?? "Backend error"
                ErrorLogger.log(message, context: "SheetSubmitter")
                return .failure(NSError(domain: "SheetSubmitter", code: 2,
                                        userInfo: [NSLocalizedDescriptionKey: message]))
            }
            return .success
        } catch {
            ErrorLogger.log(error.localizedDescription, context: "SheetSubmitter")
            return .failure(error)
        }
    }
}
