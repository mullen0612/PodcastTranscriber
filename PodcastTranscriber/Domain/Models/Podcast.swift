import Foundation

/// Represents a podcast subscription.
struct Podcast: Identifiable {
    let id: UUID
    let title: String
    let feedURL: URL
    let createdAt: Date
}