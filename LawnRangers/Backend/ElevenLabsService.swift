import Foundation

/// Voice client for the planning feature. The ElevenLabs API key lives
/// **server-side** in the Apps Script backend (Script Properties), so the app
/// never holds it. We POST to the same Web App endpoint, which proxies to
/// ElevenLabs:
///   • Speech-to-Text (Scribe) — POST {type:"voiceSTT", audio:<base64>}  → {text}
///   • Text-to-Speech (Flash)  — POST {type:"voiceTTS", text:<string>}    → {audio:<base64 MP3>}
enum ElevenLabsService {
    enum ElevenLabsError: LocalizedError {
        case notConfigured
        case http(Int, String)
        case server(String)
        case empty

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "No backend configured (Settings) — voice needs the Google Sheets backend."
            case .http(let code, let body):
                let detail = body.isEmpty ? "" : " — \(body)"
                return "Voice backend error (\(code))\(detail)."
            case .server(let msg):
                return msg
            case .empty:
                return "The voice backend returned no audio."
            }
        }
    }

    /// Voice works whenever the backend endpoint is set (the key lives there).
    static var isConfigured: Bool { BackendConfig.isConfigured }

    // MARK: - Speech-to-Text (Scribe)

    /// Transcribes a recorded audio file to text via the backend proxy.
    static func transcribe(audioURL: URL) async throws -> String {
        let audio = try Data(contentsOf: audioURL)
        let resp = try await postJSON([
            "type": "voiceSTT",
            "audio": audio.base64EncodedString(),
            "mimeType": "audio/mp4",
        ])
        if let err = resp["error"] as? String, !err.isEmpty { throw ElevenLabsError.server(err) }
        guard let text = resp["text"] as? String else { throw ElevenLabsError.empty }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Text-to-Speech

    /// Synthesizes `text` to MP3 audio data via the backend proxy.
    static func speak(_ text: String) async throws -> Data {
        let resp = try await postJSON(["type": "voiceTTS", "text": text])
        if let err = resp["error"] as? String, !err.isEmpty { throw ElevenLabsError.server(err) }
        guard let b64 = resp["audio"] as? String,
              let data = Data(base64Encoded: b64), !data.isEmpty else {
            throw ElevenLabsError.empty
        }
        return data
    }

    // MARK: - Helpers

    /// POSTs JSON to the Apps Script Web App and returns the decoded response.
    private static func postJSON(_ payload: [String: Any]) async throws -> [String: Any] {
        guard let url = BackendConfig.webAppURL else { throw ElevenLabsError.notConfigured }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ElevenLabsError.http(http.statusCode, String(body.prefix(200)))
        }
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ElevenLabsError.empty
        }
        return obj
    }
}
