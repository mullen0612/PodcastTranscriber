import Foundation

struct LocalTranscriptionService {
    private let whisperBridge = WhisperBridge()

    func transcribeLocalAudio(inputAudioURL: URL) async throws -> String {
        let modelURL = try Paths.bundleModelURL()
        let convertedWavURL = try await AudioConversionService.convertToWav(audioURL: inputAudioURL)
        defer { AudioConversionService.cleanTemporaryFiles() }

        return try whisperBridge.transcribe(audioURL: convertedWavURL, modelURL: modelURL)
    }
}
