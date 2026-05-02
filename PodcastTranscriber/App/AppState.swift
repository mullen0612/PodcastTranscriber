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

    // MARK: - Services (lazy to avoid circular deps)
    private(set) var exportService: ExportService!
    private(set) var downloadService: DownloadService!
    private(set) var transcriptionService: TranscriptionService!

    // MARK: - Podcast state
    @Published var podcasts: [Podcast] = []
    @Published var selectedPodcastID: UUID?

    init() {
        // Initialize database and run migrations
        do {
            let db = try SQLiteDatabase(path: Paths.databasePath.path)
            try Migrations.migrate(database: db)
            self.database = db
        } catch {
            fatalError("Failed to initialize database: \(error)")
        }

        // Initialize repositories
        self.podcastRepository = PodcastRepository(database: database)
        self.episodeRepository = EpisodeRepository(database: database)

        // Initialize infrastructure
        self.networkClient = NetworkClient()
        self.feedService = FeedService(networkClient: networkClient)
        self.jobQueue = JobQueue()
        self.logger = Logger()

        // Initialize services
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

        // Ensure directories exist
        do {
            try Paths.ensureDirectoriesExist()
        } catch {
            logger.log("Failed to create app directories: \(error.localizedDescription)", level: .error)
        }

        // Load initial data
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

            // Assign correct podcastID to parsed episodes and upsert
            for var episode in episodes {
                // Note: Episode is a struct with `let id, let podcastID`, so we need to
                // create a new Episode with the correct podcastID
                let correctedEpisode = Episode(
                    id: episode.id,
                    podcastID: podcastID,
                    title: episode.title,
                    pubDate: episode.pubDate,
                    enclosureURL: episode.enclosureURL,
                    status: episode.status,
                    audioPath: episode.audioPath,
                    transcriptMDPath: episode.transcriptMDPath,
                    error: episode.error,
                    updatedAt: episode.updatedAt
                )
                try episodeRepository.upsertEpisode(episode: correctedEpisode)
            }

            logger.log("Added podcast: \(title) with \(episodes.count) episodes")
            loadPodcasts()
            objectWillChange.send()
        } catch {
            logger.log("Failed to add podcast: \(error.localizedDescription)", level: .error)
        }
    }

    func deletePodcast(_ podcast: Podcast) {
        do {
            try podcastRepository.deletePodcast(id: podcast.id)
            logger.log("Deleted podcast: \(podcast.title)")
            loadPodcasts()
            objectWillChange.send()
        } catch {
            logger.log("Failed to delete podcast: \(error.localizedDescription)", level: .error)
        }
    }

    func loadEpisodes(for podcastID: UUID) -> [Episode] {
        do {
            return try episodeRepository.fetchEpisodes(forPodcastID: podcastID)
        } catch {
            logger.log("Failed to load episodes: \(error.localizedDescription)", level: .error)
            return []
        }
    }

    func updateEpisodeStatus(_ episode: Episode) {
        do {
            try episodeRepository.upsertEpisode(episode: episode)
            objectWillChange.send()
        } catch {
            logger.log("Failed to update episode: \(error.localizedDescription)", level: .error)
        }
    }

    // MARK: - Download & Transcription

    func downloadEpisode(_ episode: Episode) {
        downloadService.enqueueDownload(for: episode, appState: self)
    }

    func transcribeEpisode(_ episode: Episode) {
        transcriptionService.enqueueTranscription(for: episode, appState: self)
    }
}
