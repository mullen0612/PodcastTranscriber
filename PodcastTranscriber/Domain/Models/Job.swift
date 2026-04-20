import Foundation

/// Represents a background job for processing episodes.
struct Job {
    let id: UUID
    let episodeID: String
    let type: JobType
    let createdAt: Date
}

/// Enum for job types.
enum JobType {
    case download
    case transcribe
    case export
}