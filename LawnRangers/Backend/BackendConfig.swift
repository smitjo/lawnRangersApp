import Foundation

/// Holds the Google Sheets backend endpoint.
///
/// The app ships with a built-in default URL (`defaultWebAppURLString`) baked in,
/// so every install is connected out of the box. A value saved in Settings
/// overrides the default on that device; clearing it reverts to the default.
enum BackendConfig {
    /// Built-in default Web App URL, baked into the app.
    /// Paste your Apps Script `/exec` URL here.
    static let defaultWebAppURLString = "" // <-- paste the /exec URL here

    private static let urlKey = "sheetsWebAppURL"

    /// Per-device override saved from Settings (empty when not set).
    /// Persisted in UserDefaults (the app's preferences plist).
    static var overrideURLString: String {
        get { UserDefaults.standard.string(forKey: urlKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: urlKey) }
    }

    /// The effective URL string: the Settings override if present, else the
    /// baked-in default.
    static var webAppURLString: String {
        let override = overrideURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        return override.isEmpty ? defaultWebAppURLString : override
    }

    /// A validated URL, or nil if neither an override nor a default is set.
    static var webAppURL: URL? {
        let trimmed = webAppURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed) else { return nil }
        return url
    }

    /// Whether a usable endpoint exists (override or baked-in default).
    static var isConfigured: Bool { webAppURL != nil }

    /// True when the effective URL is the baked-in default (no Settings override).
    static var isUsingDefault: Bool {
        overrideURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !defaultWebAppURLString.isEmpty
    }
}
