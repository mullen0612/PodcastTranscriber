import Foundation
import Combine

/// Delegate that tracks download progress and signals a semaphore when done.
private class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    let semaphore = DispatchSemaphore(value: 0)
    var progressHandler: ((Double) -> Void)?
    var downloadError: Error?
    var destinationURL: URL
    var tempDownloadURL: URL?

    init(destinationURL: URL, progressHandler: ((Double) -> Void)?) {
        self.destinationURL = destinationURL
        self.progressHandler = progressHandler
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        tempDownloadURL = location
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        DispatchQueue.main.async {
            self.progressHandler?(progress)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            downloadError = error
        }
        semaphore.signal()
    }
}

/// Service for managing episode downloads via URLSession with progress tracking.
class DownloadService {
    private let episodeRepository: EpisodeRepository
    private let logger: Logger

    init(episodeRepository: EpisodeRepository, logger: Logger) {
        self.episodeRepository = episodeRepository
        self.logger = logger
    }

    func enqueueDownload(for episode: Episode, podcastTitle: String, appState: AppState) {
        appState.jobQueue.addJob { [weak self] in
            self?.performDownload(for: episode, podcastTitle: podcastTitle, appState: appState)
        }
    }

    private func performDownload(for episode: Episode, podcastTitle: String, appState: AppState) {
        let logger = self.logger

        guard let downloadURL = episode.enclosureURL else {
            logger.log("No enclosure URL for episode: \(episode.title)", level: .error)
            self.failEpisode(episode, error: "No enclosure URL", appState: appState)
            return
        }

        // Organize downloads by podcast/episode
        let podcastDir = StringSanitizer.sanitizeFileName(podcastTitle)
        let episodeFile = StringSanitizer.sanitizeFileName(episode.title)
        let ext = downloadURL.pathExtension.isEmpty ? "mp3" : downloadURL.pathExtension
        let podcastDownloadsDir = Paths.downloadsDirectory
            .appendingPathComponent(podcastDir, isDirectory: true)
        try? FileManager.default.createDirectory(at: podcastDownloadsDir, withIntermediateDirectories: true)
        let destinationURL = podcastDownloadsDir.appendingPathComponent("\(episodeFile).\(ext)")

        // Update status
        self.updateStatus(episode, status: .downloading, appState: appState)
        logger.log("Downloading: \(episode.title)")

        // Use delegate-based session for progress tracking
        let delegate = DownloadDelegate(destinationURL: destinationURL) { [weak appState] progress in
            var e = episode
            e.status = .downloading
            e.audioPath = nil
            // Store progress in a transient way — we'll use the episode's downloadProgressPercent field
            appState?.downloadProgress[episode.id] = progress
            appState?.objectWillChange.send()
        }

        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        let task = session.downloadTask(with: downloadURL)
        task.resume()

        delegate.semaphore.wait()
        session.invalidateAndCancel()

        if let error = delegate.downloadError {
            logger.log("Download failed for \(episode.title): \(error.localizedDescription)", level: .error)
            self.failEpisode(episode, error: error.localizedDescription, appState: appState)
            return
        }

        guard let tempURL = delegate.tempDownloadURL else {
            logger.log("Download failed: no file for \(episode.title)", level: .error)
            self.failEpisode(episode, error: "No downloaded file", appState: appState)
            return
        }

        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.moveItem(at: tempURL, to: destinationURL)

            var downloaded = episode
            downloaded.status = .downloaded
            downloaded.audioPath = destinationURL.path
            downloaded.error = nil
            self.updateEpisode(downloaded, appState: appState)
            logger.log("Downloaded: \(episode.title) -> \(destinationURL.path)")
        } catch {
            logger.log("Download file move failed: \(error.localizedDescription)", level: .error)
            self.failEpisode(episode, error: error.localizedDescription, appState: appState)
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
