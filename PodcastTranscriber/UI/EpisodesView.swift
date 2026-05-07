import SwiftUI
import Combine

struct EpisodesView: View {
    @EnvironmentObject var appState: AppState

    private var selectedPodcast: Podcast? {
        guard let id = appState.selectedPodcastID else { return nil }
        return appState.podcasts.first { $0.id == id }
    }

    var body: some View {
        VStack(alignment: .leading) {
            if let podcast = selectedPodcast {
                Text(podcast.title)
                    .font(.headline)
                    .padding(.horizontal)

                Text("\(appState.episodes.count) episodes")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                List(appState.episodes) { episode in
                    EpisodeRowView(
                        episode: episode,
                        downloadProgress: appState.downloadProgress[episode.id],
                        remainingTranscriptionTime: appState.remainingTranscriptionTime(for: episode.id),
                        onDownload: { appState.downloadEpisode(episode) },
                        onTranscribe: { appState.transcribeEpisode(episode) },
                        onPreview: { appState.loadTranscriptForPreview(episode) },
                        onExport: { exportEpisode(episode) }
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
        .sheet(isPresented: Binding(
            get: { appState.previewTranscriptText != nil },
            set: { if !$0 { appState.previewTranscriptText = nil } }
        )) {
            if let text = appState.previewTranscriptText {
                TranscriptPreviewView(text: text)
            }
        }
    }

    private func exportEpisode(_ episode: Episode) {
        guard let path = episode.transcriptMDPath,
              FileManager.default.fileExists(atPath: path) else {
            appState.logger.log("No transcript file to export", level: .error)
            return
        }

        if let savedURL = appState.exportService.showSavePanelAndExport(
            transcriptPath: path,
            suggestedName: episode.title
        ) {
            appState.logger.log("Exported \(episode.title) to \(savedURL.path)")
            var exported = episode
            exported.status = .exported
            appState.updateEpisodeStatus(exported)
        }
    }
}

// MARK: - Episode Row View

struct EpisodeRowView: View {
    let episode: Episode
    let downloadProgress: Double?
    let remainingTranscriptionTime: TimeInterval?
    let onDownload: () -> Void
    let onTranscribe: () -> Void
    let onPreview: () -> Void
    let onExport: () -> Void

    @State private var timer: Timer.TimerPublisher = Timer.publish(every: 1, on: .main, in: .common)
    @State private var remainingDisplay: TimeInterval?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                Text(episode.title)
                    .font(.body)
                    .lineLimit(3)

                Spacer()

                StatusBadge(status: episode.status)
            }

            HStack(spacing: 12) {
                if let pubDate = episode.pubDate {
                    Text(pubDate, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let duration = episode.duration, duration > 0 {
                    Text(formatDuration(duration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Download progress bar
            if let progress = downloadProgress, episode.status == .downloading {
                VStack(alignment: .leading, spacing: 2) {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                    Text("Downloading \(Int(progress * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 2)
            }

            // Transcription ETA countdown
            if episode.status == .transcribing, let remaining = remainingDisplay {
                VStack(alignment: .leading, spacing: 2) {
                    ProgressView()
                        .progressViewStyle(.linear)
                    Text("Estimated: \(formatDuration(remaining)) remaining")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
                .padding(.vertical, 2)
                .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
                    if let r = remainingTranscriptionTime {
                        remainingDisplay = r
                    }
                }
            }

            if let error = episode.error, !error.isEmpty {
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

                if canPreview {
                    Button("Preview") { onPreview() }
                        .controlSize(.small)
                }

                Button("Export") { onExport() }
                    .disabled(!canExport)
                    .controlSize(.small)
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 2)
        .onAppear {
            remainingDisplay = remainingTranscriptionTime
        }
    }

    private var canDownload: Bool {
        episode.status == .discovered && episode.enclosureURL != nil
    }

    private var canTranscribe: Bool {
        episode.status == .downloaded && episode.audioPath != nil
    }

    private var canPreview: Bool {
        (episode.status == .transcribed || episode.status == .exported)
            && episode.transcriptMDPath != nil
    }

    private var canExport: Bool {
        canPreview
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        if mins >= 60 {
            let hrs = mins / 60
            let m = mins % 60
            return String(format: "%d:%02d:%02d", hrs, m, secs)
        }
        return String(format: "%d:%02d", mins, secs)
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

// MARK: - Transcript Preview

struct TranscriptPreviewView: View {
    let text: String

    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button("Close") {
                    NSApp.keyWindow?.close()
                }
                .padding()
            }
            ScrollView {
                Text(text)
                    .font(.body)
                    .textSelection(.enabled)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }
}
