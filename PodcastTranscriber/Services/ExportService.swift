import Foundation

/// Service for exporting episode transcripts to Markdown.
class ExportService {
    func exportMarkdown(for episode: Episode, transcript: Transcript) throws {
        let sanitizedPodcastTitle = StringSanitizer.sanitizeFileName(episode.title)
        let exportPath = Paths.exportsDirectory
            .appendingPathComponent(sanitizedPodcastTitle, isDirectory: true)
            .appendingPathComponent("\(episode.updatedAt.timeIntervalSince1970).md")

        let markdownContent = """
        # \(episode.title)
        ## Transcript
        \(transcript.content)
        """

        try FileManager.default.createDirectory(at: exportPath.deletingLastPathComponent(), withIntermediateDirectories: true)
        try markdownContent.write(to: exportPath, atomically: true, encoding: .utf8)
        print("Exported Markdown to \(exportPath.path)")
    }

    func export(text: String, suggestedName: String) throws -> URL {
        let exportsDirectory = Paths.exportsDirectory
        try FileManager.default.createDirectory(at: exportsDirectory, withIntermediateDirectories: true)

        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)
        let fileName = "\(suggestedName)-transcript-\(timestamp).txt"
        let fileURL = exportsDirectory.appendingPathComponent(fileName)

        try text.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
}
