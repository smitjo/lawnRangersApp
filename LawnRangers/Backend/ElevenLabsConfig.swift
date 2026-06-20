import Foundation

/// Holds the ElevenLabs voice-AI credentials used for the voice planning feature
/// (speech-to-text via Scribe, text-to-speech for spoken confirmations).
///
/// The API key is per-device and entered in Settings (never baked into the app,
/// so it isn't committed to the repo). The voice ID has a sensible built-in
/// default that the user can override.
enum ElevenLabsConfig {
    private static let apiKeyKey = "elevenLabsAPIKey"
    private static let voiceIDKey = "elevenLabsVoiceID"

    /// ElevenLabs default public voice ("Rachel").
    static let defaultVoiceID = "21m00Tcm4TlvDq8ikWAM"

    /// Low-latency model good for short, conversational confirmations.
    static let ttsModelID = "eleven_flash_v2_5"
    /// Scribe speech-to-text model.
    static let sttModelID = "scribe_v1"

    /// Per-device API key saved from Settings (empty when not set).
    static var apiKey: String {
        get { UserDefaults.standard.string(forKey: apiKeyKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: apiKeyKey) }
    }

    /// Voice used for spoken confirmations; falls back to the built-in default.
    static var voiceID: String {
        get {
            let v = (UserDefaults.standard.string(forKey: voiceIDKey) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return v.isEmpty ? defaultVoiceID : v
        }
        set { UserDefaults.standard.set(newValue, forKey: voiceIDKey) }
    }

    /// Whether the voice features can be used (an API key has been entered).
    static var isConfigured: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
