import Foundation

/// Swift wrapper for WhisperBridge.
struct WhisperBridge {
    func transcribe(audioURL: URL, modelURL: URL, language: WhisperLanguage) throws -> Transcript {
        // WHISPER-INTEGRATION-TODO: Call C function from WhisperBridge.h
        print("Transcribing audio at \(audioURL.path) with model \(modelURL.path)")
        return Transcript(episodeID: UUID().uuidString, content: "Stub transcript")
    }
}