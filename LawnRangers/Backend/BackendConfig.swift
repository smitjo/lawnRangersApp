import Foundation

/// Holds the Google Sheets backend endpoint. Until you paste a Web App URL
/// (in Settings), the app simply saves entries locally and skips submission.
///
/// To connect the backend at the end: deploy the Apps Script in `backend/Code.gs`
/// as a Web App, then paste its URL into the app's Settings screen.
enum BackendConfig {
    private static let urlKey = "sheetsWebAppURL"

    /// The raw Web App URL string, persisted in UserDefaults.
    static var webAppURLString: String {
        get { UserDefaults.standard.string(forKey: urlKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: urlKey) }
    }

    /// A validated URL, or nil if not configured yet.
    static var webAppURL: URL? {
        let trimmed = webAppURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed) else { return nil }
        return url
    }

    /// Whether a backend endpoint has been configured.
    static var isConfigured: Bool { webAppURL != nil }
}
