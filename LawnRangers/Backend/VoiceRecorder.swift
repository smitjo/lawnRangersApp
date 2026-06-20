import Foundation
import AVFoundation

/// Records a short voice memo to an m4a file (for ElevenLabs Scribe) and plays
/// back synthesized MP3 audio (from ElevenLabs TTS). Handles the microphone
/// permission prompt and audio-session setup.
@MainActor
final class VoiceRecorder: NSObject, ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var isPlaying = false

    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var fileURL: URL?

    /// Asks for microphone permission (no-op if already granted/denied).
    func requestPermission() async -> Bool {
        await withCheckedContinuation { cont in
            AVAudioApplication.requestRecordPermission { granted in
                cont.resume(returning: granted)
            }
        }
    }

    /// Begins recording to a fresh temp file. Returns false if the mic is denied
    /// or the session can't start.
    @discardableResult
    func startRecording() async -> Bool {
        guard await requestPermission() else { return false }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)

            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("voice-\(UUID().uuidString).m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 16_000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
            ]
            let rec = try AVAudioRecorder(url: url, settings: settings)
            rec.record()
            recorder = rec
            fileURL = url
            isRecording = true
            return true
        } catch {
            ErrorLogger.log(error.localizedDescription, context: "VoiceRecorder.start")
            return false
        }
    }

    /// Stops recording and returns the file URL of the captured audio.
    func stopRecording() -> URL? {
        recorder?.stop()
        recorder = nil
        isRecording = false
        return fileURL
    }

    /// Plays back MP3 audio (e.g. an ElevenLabs TTS confirmation).
    func play(_ data: Data) {
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            let p = try AVAudioPlayer(data: data)
            p.delegate = self
            p.play()
            player = p
            isPlaying = true
        } catch {
            ErrorLogger.log(error.localizedDescription, context: "VoiceRecorder.play")
        }
    }
}

extension VoiceRecorder: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.isPlaying = false }
    }
}
