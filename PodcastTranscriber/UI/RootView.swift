import SwiftUI

enum NavItem: String, Identifiable, CaseIterable {
    case podcasts = "Podcasts"
    case localTranscribe = "Local Transcribe"
    case logs = "Logs"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .podcasts: return "antenna.radiowaves.left.and.right"
        case .localTranscribe: return "mic"
        case .logs: return "list.bullet.rectangle"
        }
    }
}

struct RootView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedNav: NavItem = .podcasts

    var body: some View {
        NavigationSplitView {
            List(NavItem.allCases, selection: $selectedNav) { item in
                Label(item.rawValue, systemImage: item.icon)
                    .tag(item)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            switch selectedNav {
            case .podcasts:
                HSplitView {
                    SubscriptionsView()
                        .frame(minWidth: 250, idealWidth: 300)
                    EpisodesView()
                        .frame(minWidth: 350, idealWidth: 500)
                }
            case .localTranscribe:
                LocalTranscribeView()
            case .logs:
                LogsView()
            }
        }
        .navigationTitle("Podcast Transcriber")
    }
}
