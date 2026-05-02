import Foundation

/// Service for managing episode transcriptions via whisper.cpp.
class TranscriptionService {
    private let episodeRepository: EpisodeRepository
    private let exportService: ExportService
    private let logger: Logger

    init(episodeRepository: EpisodeRepository, exportService: ExportService, logger: Logger) {
        self.episodeRepository = episodeRepository
        self.exportService = exportService
        self.logger = logger
    }

    func enqueueTranscription(for episode: Episode, appState: AppState) {
        appState.jobQueue.addJob { [weak self] in
            self?.performTranscription(for: episode, appState: appState)
        }
    }

    private func performTranscription(for episode: Episode, appState: AppState) {
        let logger = self.logger

        guard let audioPath = episode.audioPath else {
            logger.log("No audio path for episode: \(episode.title)", level: .error)
            var failed = episode
            failed.status = .failed
            failed.error = "No audio file available"
            appState.updateEpisodeStatus(failed)
            return
        }

        let audioURL = URL(fileURLWithPath: audioPath)
        guard FileManager.default.fileExists(atPath: audioPath) else {
            logger.log("Audio file not found at \(audioPath)", level: .error)
            var failed = episode
            failed.status = .failed
            failed.error = "Audio file missing"
            appState.updateEpisodeStatus(failed)
            return
        }

        // Update status to transcribing
        var transcribing = episode
        transcribing.status = .transcribing
        appState.updateEpisodeStatus(transcribing)
        logger.log("Transcribing: \(episode.title)")

        let semaphore = DispatchSemaphore(value: 0)
        var transcriptionText: String?
        var transcriptionError: Error?

        // Run transcription on a background task
        Task {
            do {
                let service = LocalTranscriptionService()
                transcriptionText = try await service.transcribeLocalAudio(inputAudioURL: audioURL)
            } catch {
                transcriptionError = error
            }
            semaphore.signal()
        }

        semaphore.wait()

        if let error = transcriptionError {
            logger.log("Transcription failed for \(episode.title): \(error.localizedDescription)", level: .error)
            var failed = episode
            failed.status = .failed
            failed.error = error.localizedDescription
            appState.updateEpisodeStatus(failed)
            return
        }

        guard let text = transcriptionText else {
            logger.log("Transcription returned empty for \(episode.title)", level: .error)
            var failed = episode
            failed.status = .failed
            failed.error = "Transcription returned empty result"
            appState.updateEpisodeStatus(failed)
            return
        }

        // Export the transcript
        do {
            let transcript = Transcript(episodeID: episode.id, content: text)
            try exportService.exportMarkdown(for: episode, transcript: transcript)

            var transcribed = episode
            transcribed.status = .transcribed
            transcribed.error = nil
            appState.updateEpisodeStatus(transcribed)
            logger.log("Transcribed: \(episode.title)")
        } catch {
            logger.log("Export failed for \(episode.title): \(error.localizedDescription)", level: .error)
            var failed = episode
            failed.status = .failed
            failed.error = "Export failed: \(error.localizedDescription)"
            appState.updateEpisodeStatus(failed)
        }
    }
}
