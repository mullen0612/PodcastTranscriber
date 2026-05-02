import Foundation

/// Swift wrapper for the pt_whisper_transcribe C function declared in WhisperBridge.h.
struct WhisperBridge {

    /// Transcribes audio using whisper.cpp and returns the raw text result.
    /// - Parameters:
    ///   - audioURL: Path to a WAV file (16kHz, mono, 16-bit PCM).
    ///   - modelURL: Path to the whisper model file (e.g. ggml-base.en.bin).
    /// - Returns: The transcription text.
    func transcribe(audioURL: URL, modelURL: URL) throws -> String {
        let outputURL = Paths.temporaryDirectory()
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("txt")

        let resultCode = pt_whisper_transcribe(
            modelURL.path,
            audioURL.path,
            outputURL.path
        )

        if resultCode != 0 {
            throw PodcastTranscriberError.whisperFailed(code: Int(resultCode))
        }

        return try String(contentsOf: outputURL, encoding: .utf8)
    }
}
