import Foundation
import AppKit
import UniformTypeIdentifiers

/// Service for exporting episode transcripts to Markdown.
class ExportService {

    /// Exports transcript to a Markdown file, organized by podcast title.
    /// Returns the file URL of the saved transcript.
    func exportMarkdown(for episode: Episode, podcastTitle: String, transcript: Transcript) throws -> URL {
        let podcastDir = StringSanitizer.sanitizeFileName(podcastTitle)
        let episodeFile = StringSanitizer.sanitizeFileName(episode.title)

        let exportDir = Paths.exportsDirectory
            .appendingPathComponent(podcastDir, isDirectory: true)
        try FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)

        let exportPath = exportDir.appendingPathComponent("\(episodeFile).md")

        let dateStr = episode.pubDate.map {
            DateFormatter.localizedString(from: $0, dateStyle: .medium, timeStyle: .none)
        } ?? "Unknown date"

        let markdownContent = """
        # \(episode.title)
        **Podcast:** \(podcastTitle)
        **Published:** \(dateStr)

        ## Transcript
        \(transcript.content)
        """

        try markdownContent.write(to: exportPath, atomically: true, encoding: .utf8)
        return exportPath
    }

    /// Exports raw text to a user-chosen location via NSSavePanel.
    /// Call this from the main thread.
    func showSavePanelAndExport(transcriptPath: String, suggestedName: String) -> URL? {
        let panel = NSSavePanel()
        panel.title = "Export Transcript"
        panel.nameFieldStringValue = "\(suggestedName).md"
        panel.allowedContentTypes = [.plainText]

        guard panel.runModal() == .OK, let saveURL = panel.url else {
            return nil
        }

        do {
            let content = try String(contentsOfFile: transcriptPath, encoding: .utf8)
            try content.write(to: saveURL, atomically: true, encoding: .utf8)
            return saveURL
        } catch {
            return nil
        }
    }
}
