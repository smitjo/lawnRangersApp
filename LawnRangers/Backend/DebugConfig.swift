import Foundation

/// Developer/debug settings, persisted in UserDefaults.
enum DebugConfig {
    private static let errorLoggingKey = "debugErrorLogging"

    /// When on, app errors are logged to an "Errors" tab in the Google Sheet.
    static var errorLoggingEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: errorLoggingKey) }
        set { UserDefaults.standard.set(newValue, forKey: errorLoggingKey) }
    }
}
