import SwiftUI

struct EpisodesView: View {
    @EnvironmentObject var appState: AppState

    private var selectedPodcast: Podcast? {
        guard let id = appState.selectedPodcastID else { return nil }
        return appState.podcasts.first { $0.id == id }
    }

    private var episodes: [Episode] {
        guard let podcast = selectedPodcast else { return [] }
        return appState.loadEpisodes(for: podcast.id)
    }

    var body: some View {
        VStack(alignment: .leading) {
            if let podcast = selectedPodcast {
                Text(podcast.title)
                    .font(.headline)
                    .padding(.horizontal)

                Text("\(episodes.count) episodes")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                List(episodes) { episode in
                    EpisodeRowView(
                        episode: episode,
                        onDownload: { appState.downloadEpisode(episode) },
                        onTranscribe: { appState.transcribeEpisode(episode) },
                        onExport: {
                            exportEpisode(episode)
                        }
                    )
                }
                .listStyle(.inset)
            } else {
                Text("Select a podcast to see episodes")
                    .foregroundColor(.secondary)
                    .padding()
                Spacer()
            }
        }
        .padding(.vertical)
    }

    private func exportEpisode(_ episode: Episode) {
        do {
            let content = try loadTranscriptContent(for: episode)
            let url = try appState.exportService.export(
                text: content,
                suggestedName: episode.title
            )
            appState.logger.log("Exported \(episode.title) to \(url.path)")

            var exported = episode
            exported.status = .exported
            appState.updateEpisodeStatus(exported)
        } catch {
            appState.logger.log("Export failed: \(error.localizedDescription)", level: .error)
        }
    }

    private func loadTranscriptContent(for episode: Episode) throws -> String {
        guard let transcriptPath = episode.transcriptMDPath else {
            throw NSError(domain: "EpisodesView", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No transcript available"])
        }
        return try String(contentsOfFile: transcriptPath, encoding: .utf8)
    }
}

// MARK: - Episode Row View

struct EpisodeRowView: View {
    let episode: Episode
    let onDownload: () -> Void
    let onTranscribe: () -> Void
    let onExport: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(episode.title)
                    .font(.body)
                    .lineLimit(2)

                Spacer()

                StatusBadge(status: episode.status)
            }

            if let pubDate = episode.pubDate {
                Text(pubDate, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let error = episode.error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .lineLimit(2)
            }

            HStack(spacing: 8) {
                Button("Download") { onDownload() }
                    .disabled(!canDownload)
                    .controlSize(.small)

                Button("Transcribe") { onTranscribe() }
                    .disabled(!canTranscribe)
                    .controlSize(.small)

                Button("Export") { onExport() }
                    .disabled(!canExport)
                    .controlSize(.small)
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 2)
    }

    private var canDownload: Bool {
        episode.status == .discovered && episode.enclosureURL != nil
    }

    private var canTranscribe: Bool {
        episode.status == .downloaded && episode.audioPath != nil
    }

    private var canExport: Bool {
        episode.status == .transcribed || episode.status == .exported
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: EpisodeStatus

    var body: some View {
        Text(status.rawValue)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(backgroundColor)
            .foregroundColor(.white)
            .cornerRadius(4)
    }

    private var backgroundColor: Color {
        switch status {
        case .discovered: return .gray
        case .downloading: return .blue
        case .downloaded: return .green
        case .transcribing: return .orange
        case .transcribed: return .purple
        case .exported: return .teal
        case .failed: return .red
        }
    }
}
