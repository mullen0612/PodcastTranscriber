//
//  ContentView.swift
//  PodcastTranscriber
//
//  Created by Mullen  Char  on 2026/4/20.
//

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

#Preview {
    RootView()
}
