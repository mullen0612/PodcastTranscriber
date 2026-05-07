import Foundation
import Combine

/// AppState serves as the global dependency injection container and state manager.
class AppState: ObservableObject {
    let objectWillChange = PassthroughSubject<Void, Never>()

    // MARK: - Persistence
    let database: SQLiteDatabase
    let podcastRepository: PodcastRepository
    let episodeRepository: EpisodeRepository

    // MARK: - Infrastructure
    let networkClient: NetworkClient
    let feedService: FeedService
    let jobQueue: JobQueue
    let logger: Logger

    // MARK: - Services
    let exportService: ExportService
    let downloadService: DownloadService
    let transcriptionService: TranscriptionService

    // MARK: - Podcast state
    @Published var podcasts: [Podcast] = []
    @Published var selectedPodcastID: UUID? {
        didSet { loadEpisodesForSelection() }
    }
    @Published var episodes: [Episode] = []

    // MARK: - Download progress (episodeID -> fraction 0...1)
    @Published var downloadProgress: [String: Double] = [:]

    // MARK: - Transcription ETA
    @Published var transcriptionStartTime: [String: Date] = [:]
    @Published var transcriptionETA: [String: TimeInterval] = [:]

    // MARK: - Transcript preview
    @Published var previewTranscriptText: String? = nil
    @Published var previewTranscriptEpisodeID: String? = nil

    init() {
        do {
            let db = try SQLiteDatabase(path: Paths.databasePath.path)
            try Migrations.migrate(database: db)
            self.database = db
        } catch {
            fatalError("Failed to initialize database: \(error)")
        }

        self.podcastRepository = PodcastRepository(database: database)
        self.episodeRepository = EpisodeRepository(database: database)
        self.networkClient = NetworkClient()
        self.feedService = FeedService(networkClient: networkClient)
        self.jobQueue = JobQueue()
        self.logger = Logger()
        self.exportService = ExportService()
        self.downloadService = DownloadService(
            episodeRepository: episodeRepository,
            logger: logger
        )
        self.transcriptionService = TranscriptionService(
            episodeRepository: episodeRepository,
            exportService: exportService,
            logger: logger
        )

        do {
            try Paths.ensureDirectoriesExist()
        } catch {
            logger.log("Failed to create app directories: \(error.localizedDescription)", level: .error)
        }

        loadPodcasts()
    }

    // MARK: - Data loading

    func loadPodcasts() {
        do {
            podcasts = try podcastRepository.fetchAllPodcasts()
        } catch {
            logger.log("Failed to load podcasts: \(error.localizedDescription)", level: .error)
        }
    }

    private func loadEpisodesForSelection() {
        guard let id = selectedPodcastID else {
            episodes = []
            return
        }
        do {
            episodes = try episodeRepository.fetchEpisodes(forPodcastID: id)
        } catch {
            logger.log("Failed to load episodes: \(error.localizedDescription)", level: .error)
            episodes = []
        }
    }

    func addPodcast(from feedURL: URL) async {
        do {
            logger.log("Fetching feed from \(feedURL.absoluteString)")
            let (title, episodes) = try await feedService.fetchFeed(from: feedURL)

            let podcastID = UUID()
            try podcastRepository.addPodcast(
                id: podcastID,
                title: title,
                feedURL: feedURL.absoluteString,
                createdAt: Date()
            )

            for episode in episodes {
                let corrected = Episode(
                    id: episode.id,
                    podcastID: podcastID,
                    title: episode.title,
                    pubDate: episode.pubDate,
                    enclosureURL: episode.enclosureURL,
                    status: episode.status,
                    audioPath: episode.audioPath,
                    transcriptMDPath: episode.transcriptMDPath,
                    error: episode.error,
                    duration: episode.duration,
                    updatedAt: episode.updatedAt
                )
                try episodeRepository.upsertEpisode(episode: corrected)
            }

            logger.log("Added podcast: \(title) with \(episodes.count) episodes")

            await MainActor.run { [weak self] in
                self?.loadPodcasts()
                self?.objectWillChange.send()
            }
        } catch {
            logger.log("Failed to add podcast: \(error.localizedDescription)", level: .error)
        }
    }

    func deletePodcast(_ podcast: Podcast) {
        do {
            try podcastRepository.deletePodcast(id: podcast.id)
            logger.log("Deleted podcast: \(podcast.title)")
            if selectedPodcastID == podcast.id {
                selectedPodcastID = nil
            }
            loadPodcasts()
            objectWillChange.send()
        } catch {
            logger.log("Failed to delete podcast: \(error.localizedDescription)", level: .error)
        }
    }

    func updateEpisodeStatus(_ episode: Episode) {
        do {
            try episodeRepository.upsertEpisode(episode: episode)
        } catch {
            logger.log("Failed to update episode: \(error.localizedDescription)", level: .error)
        }
        DispatchQueue.main.async { [weak self] in
            self?.loadEpisodesForSelection()
            self?.objectWillChange.send()
        }
    }

    // MARK: - Download & Transcription

    func podcastTitle(for episode: Episode) -> String {
        return podcasts.first(where: { $0.id == episode.podcastID })?.title ?? "Unknown"
    }

    func downloadEpisode(_ episode: Episode) {
        let title = podcastTitle(for: episode)
        downloadService.enqueueDownload(for: episode, podcastTitle: title, appState: self)
    }

    func transcribeEpisode(_ episode: Episode) {
        let title = podcastTitle(for: episode)

        // Calculate ETA from duration (whisper base CPU ~4x real-time)
        if let duration = episode.duration, duration > 0 {
            let eta = duration * 4.0
            transcriptionETA[episode.id] = eta
            transcriptionStartTime[episode.id] = Date()
        }

        transcriptionService.enqueueTranscription(for: episode, podcastTitle: title, appState: self)
    }

    /// Returns remaining transcription time in seconds, or nil if not available.
    func remainingTranscriptionTime(for episodeID: String) -> TimeInterval? {
        guard let start = transcriptionStartTime[episodeID],
              let eta = transcriptionETA[episodeID] else { return nil }
        let elapsed = Date().timeIntervalSince(start)
        let remaining = eta - elapsed
        return remaining > 0 ? remaining : 0
    }

    func loadTranscriptForPreview(_ episode: Episode) {
        guard let path = episode.transcriptMDPath,
              let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            return
        }
        previewTranscriptEpisodeID = episode.id
        previewTranscriptText = content
    }
}
