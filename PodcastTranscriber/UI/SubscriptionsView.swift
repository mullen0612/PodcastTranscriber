import SwiftUI

struct SubscriptionsView: View {
    @EnvironmentObject var appState: AppState
    @State private var feedURLString: String = ""
    @State private var isAdding: Bool = false

    var body: some View {
        VStack(alignment: .leading) {
            Text("Subscriptions")
                .font(.headline)
                .padding(.horizontal)

            // Add feed input
            HStack {
                TextField("Feed URL", text: $feedURLString)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isAdding)

                Button(action: addFeed) {
                    if isAdding {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Add")
                    }
                }
                .disabled(feedURLString.trimmingCharacters(in: .whitespaces).isEmpty || isAdding)
            }
            .padding(.horizontal)
            .padding(.bottom, 4)

            // Podcast list
            List(selection: $appState.selectedPodcastID) {
                ForEach(appState.podcasts) { podcast in
                    VStack(alignment: .leading) {
                        Text(podcast.title)
                            .font(.body)
                            .lineLimit(2)
                        Text(podcast.feedURL.absoluteString)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    .padding(.vertical, 2)
                    .tag(podcast.id)
                }
                .onDelete(perform: deletePodcasts)
            }
            .listStyle(.inset)
        }
        .padding(.vertical)
    }

    private func addFeed() {
        let trimmed = feedURLString.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let url = URL(string: trimmed) else { return }

        isAdding = true
        Task {
            await appState.addPodcast(from: url)
            await MainActor.run {
                feedURLString = ""
                isAdding = false
            }
        }
    }

    private func deletePodcasts(at offsets: IndexSet) {
        for index in offsets {
            let podcast = appState.podcasts[index]
            appState.deletePodcast(podcast)
        }
    }
}
