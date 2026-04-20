import Foundation

/// Manages application-specific paths.
struct Paths {
    static let applicationSupportDirectory: URL = {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupport = paths[0].appendingPathComponent("PodcastTranscriber", isDirectory: true)
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        return appSupport
    }()

    static var databasePath: URL {
        applicationSupportDirectory.appendingPathComponent("podcasttranscriber.sqlite3")
    }

    static var downloadsDirectory: URL {
        applicationSupportDirectory.appendingPathComponent("Downloads", isDirectory: true)
    }

    static var exportsDirectory: URL {
        applicationSupportDirectory.appendingPathComponent("Exports", isDirectory: true)
    }

    static var logsDirectory: URL {
        applicationSupportDirectory.appendingPathComponent("Logs", isDirectory: true)
    }

    static func bundleModelURL() throws -> URL {
        guard let url = Bundle.main.url(forResource: "models/ggml-base.en", withExtension: "bin") else {
            throw PodcastTranscriberError.modelNotFound
        }
        return url
    }
}

/// Custom error type for the application.
enum PodcastTranscriberError: Error {
    case modelNotFound
}