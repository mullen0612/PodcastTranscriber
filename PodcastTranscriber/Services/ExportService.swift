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
}