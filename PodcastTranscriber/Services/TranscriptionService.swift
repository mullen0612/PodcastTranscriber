import Foundation
import Combine

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

    func enqueueTranscription(for episode: Episode, podcastTitle: String, appState: AppState) {
        appState.jobQueue.addJob { [weak self] in
            self?.performTranscription(for: episode, podcastTitle: podcastTitle, appState: appState)
        }
    }

    private func performTranscription(for episode: Episode, podcastTitle: String, appState: AppState) {
        let logger = self.logger

        guard let audioPath = episode.audioPath else {
            logger.log("No audio path for episode: \(episode.title)", level: .error)
            self.failEpisode(episode, error: "No audio file available", appState: appState)
            return
        }

        let audioURL = URL(fileURLWithPath: audioPath)
        guard FileManager.default.fileExists(atPath: audioPath) else {
            logger.log("Audio file not found at \(audioPath)", level: .error)
            self.failEpisode(episode, error: "Audio file missing", appState: appState)
            return
        }

        // Update status to transcribing
        self.updateStatus(episode, status: .transcribing, appState: appState)
        logger.log("Transcribing: \(episode.title)")

        let semaphore = DispatchSemaphore(value: 0)
        var transcriptionText: String?
        var transcriptionError: Error?

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
            self.failEpisode(episode, error: error.localizedDescription, appState: appState)
            return
        }

        guard let text = transcriptionText, !text.isEmpty else {
            logger.log("Transcription returned empty for \(episode.title)", level: .error)
            self.failEpisode(episode, error: "Transcription returned empty result", appState: appState)
            return
        }

        // Export and save
        do {
            let transcript = Transcript(episodeID: episode.id, content: text)
            let exportedURL = try exportService.exportMarkdown(
                for: episode,
                podcastTitle: podcastTitle,
                transcript: transcript
            )

            var transcribed = episode
            transcribed.status = .transcribed
            transcribed.transcriptMDPath = exportedURL.path
            transcribed.error = nil
            self.updateEpisode(transcribed, appState: appState)
            logger.log("Transcribed: \(episode.title) -> \(exportedURL.path)")
        } catch {
            logger.log("Export failed for \(episode.title): \(error.localizedDescription)", level: .error)
            self.failEpisode(episode, error: "Export failed: \(error.localizedDescription)", appState: appState)
        }
    }

    // MARK: - Helpers (dispatch UI updates to main thread)

    private func updateStatus(_ episode: Episode, status: EpisodeStatus, appState: AppState) {
        var e = episode
        e.status = status
        updateEpisode(e, appState: appState)
    }

    private func failEpisode(_ episode: Episode, error: String, appState: AppState) {
        var e = episode
        e.status = .failed
        e.error = error
        updateEpisode(e, appState: appState)
    }

    private func updateEpisode(_ episode: Episode, appState: AppState) {
        do {
            try episodeRepository.upsertEpisode(episode: episode)
        } catch {
            logger.log("DB write failed: \(error.localizedDescription)", level: .error)
        }
        DispatchQueue.main.async {
            appState.objectWillChange.send()
        }
    }
}
