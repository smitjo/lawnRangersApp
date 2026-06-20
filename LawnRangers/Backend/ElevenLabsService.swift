import Foundation

/// Thin client for the two ElevenLabs REST endpoints the app uses:
///   • Speech-to-Text (Scribe) — POST /v1/speech-to-text  (multipart audio → text)
///   • Text-to-Speech (Flash)  — POST /v1/text-to-speech/{voiceId}  (text → MP3)
///
/// The API key is read from `ElevenLabsConfig` and sent in the `xi-api-key`
/// header. Network/HTTP failures throw an `ElevenLabsError` with a friendly,
/// user-facing message.
enum ElevenLabsService {
    private static let base = URL(string: "https://api.elevenlabs.io")!

    enum ElevenLabsError: LocalizedError {
        case notConfigured
        case http(Int, String)
        case empty

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "Add your ElevenLabs API key in Settings to use voice."
            case .http(let code, let body):
                let detail = body.isEmpty ? "" : " — \(body)"
                return "ElevenLabs error (\(code))\(detail)."
            case .empty:
                return "ElevenLabs returned no audio."
            }
        }
    }

    // MARK: - Speech-to-Text (Scribe)

    /// Transcribes a recorded audio file to text via Scribe.
    static func transcribe(audioURL: URL) async throws -> String {
        let key = ElevenLabsConfig.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw ElevenLabsError.notConfigured }

        let url = base.appendingPathComponent("/v1/speech-to-text")
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(key, forHTTPHeaderField: "xi-api-key")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let audio = try Data(contentsOf: audioURL)
        var body = Data()
        body.appendFormField("model_id", value: ElevenLabsConfig.sttModelID, boundary: boundary)
        body.appendFileField("file", filename: "audio.m4a", mimeType: "audio/mp4",
                             fileData: audio, boundary: boundary)
        body.append("--\(boundary)--\r\n")
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        try check(response, data)

        let decoded = try JSONDecoder().decode(ScribeResponse.self, from: data)
        return decoded.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private struct ScribeResponse: Decodable { let text: String }

    // MARK: - Text-to-Speech

    /// Synthesizes `text` to MP3 audio data using the configured voice.
    static func speak(_ text: String) async throws -> Data {
        let key = ElevenLabsConfig.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw ElevenLabsError.notConfigured }

        let url = base.appendingPathComponent("/v1/text-to-speech/\(ElevenLabsConfig.voiceID)")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(key, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "text": text,
            "model_id": ElevenLabsConfig.ttsModelID,
            "voice_settings": ["stability": 0.5, "similarity_boost": 0.75],
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        try check(response, data)
        guard !data.isEmpty else { throw ElevenLabsError.empty }
        return data
    }

    // MARK: - Helpers

    private static func check(_ response: URLResponse, _ data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        if !(200...299).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ElevenLabsError.http(http.statusCode, String(body.prefix(200)))
        }
    }
}

// MARK: - Multipart form helpers

private extension Data {
    mutating func append(_ string: String) {
        if let d = string.data(using: .utf8) { append(d) }
    }

    mutating func appendFormField(_ name: String, value: String, boundary: String) {
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        append("\(value)\r\n")
    }

    mutating func appendFileField(_ name: String, filename: String, mimeType: String,
                                  fileData: Data, boundary: String) {
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
        append("Content-Type: \(mimeType)\r\n\r\n")
        append(fileData)
        append("\r\n")
    }
}
