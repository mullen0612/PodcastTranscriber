import Foundation

/// Represents an episode of a podcast.
struct Episode: Identifiable {
    let id: String
    let podcastID: UUID
    let title: String
    let pubDate: Date?
    let enclosureURL: URL?
    var status: EpisodeStatus
    var audioPath: String?
    var transcriptMDPath: String?
    var error: String?
    let duration: TimeInterval?  // seconds
    let updatedAt: Date
}
