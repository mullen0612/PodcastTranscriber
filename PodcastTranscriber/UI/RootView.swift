import SwiftUI

struct RootView: View {
    var body: some View {
        NavigationSplitView {
            SubscriptionsView()
        } detail: {
            EpisodesView()
        }
        .navigationTitle("Podcast Transcriber")
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
    }
}