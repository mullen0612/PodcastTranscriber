import Foundation

/// Enum representing the status of an episode.
enum EpisodeStatus: String {
    case discovered
    case downloading
    case downloaded
    case transcribing
    case transcribed
    case exported
    case failed
}