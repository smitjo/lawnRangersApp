import Foundation
import UIKit

/// Best-effort error logging to an "Errors" tab in the Google Sheet, gated by the
/// Settings debug flag (`DebugConfig.errorLoggingEnabled`).
///
/// Fire-and-forget: it never throws and silently ignores its own failures, so it
/// can't cause an error loop (e.g. logging a network failure over the same
/// network). Does nothing when the flag is off or no backend URL is configured.
enum ErrorLogger {
    static func log(_ message: String, context: String) {
        guard DebugConfig.errorLoggingEnabled, let url = BackendConfig.webAppURL else { return }
        let payload: [String: Any] = [
            "type": "error",
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "context": context,
            "message": message,
            "device": "iOS \(UIDevice.current.systemVersion)",
        ]
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return }
        Task {
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = body
            _ = try? await URLSession.shared.data(for: req)
        }
    }
}
