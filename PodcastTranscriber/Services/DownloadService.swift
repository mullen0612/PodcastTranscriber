import Foundation

/// Service for managing episode downloads via URLSession.
class DownloadService {
    private let episodeRepository: EpisodeRepository
    private let logger: Logger

    init(episodeRepository: EpisodeRepository, logger: Logger) {
        self.episodeRepository = episodeRepository
        self.logger = logger
    }

    func enqueueDownload(for episode: Episode, appState: AppState) {
        appState.jobQueue.addJob { [weak self] in
            self?.performDownload(for: episode, appState: appState)
        }
    }

    private func performDownload(for episode: Episode, appState: AppState) {
        let logger = self.logger

        guard let downloadURL = episode.enclosureURL else {
            logger.log("No enclosure URL for episode: \(episode.title)", level: .error)
            var failed = episode
            failed.status = .failed
            failed.error = "No enclosure URL"
            appState.updateEpisodeStatus(failed)
            return
        }

        // Update status to downloading
        var downloading = episode
        downloading.status = .downloading
        appState.updateEpisodeStatus(downloading)
        logger.log("Downloading: \(episode.title)")

        // Ensure downloads directory exists
        let downloadsDir = Paths.downloadsDirectory
        try? FileManager.default.createDirectory(at: downloadsDir, withIntermediateDirectories: true)

        let fileName = downloadURL.lastPathComponent
        let destinationURL = downloadsDir.appendingPathComponent(fileName)

        let semaphore = DispatchSemaphore(value: 0)
        var downloadError: Error?

        let task = URLSession.shared.downloadTask(with: downloadURL) { tempURL, _, error in
            defer { semaphore.signal() }

            if let error = error {
                downloadError = error
                return
            }

            guard let tempURL = tempURL else {
                downloadError = NSError(domain: "DownloadService", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "No downloaded file"])
                return
            }

            do {
                // Remove existing file if present
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.moveItem(at: tempURL, to: destinationURL)
            } catch {
                downloadError = error
            }
        }

        task.resume()
        semaphore.wait()

        if let error = downloadError {
            logger.log("Download failed for \(episode.title): \(error.localizedDescription)", level: .error)
            var failed = episode
            failed.status = .failed
            failed.error = error.localizedDescription
            appState.updateEpisodeStatus(failed)
        } else {
            logger.log("Downloaded: \(episode.title) to \(destinationURL.path)")
            var downloaded = episode
            downloaded.status = .downloaded
            downloaded.audioPath = destinationURL.path
            downloaded.error = nil
            appState.updateEpisodeStatus(downloaded)
        }
    }
}
