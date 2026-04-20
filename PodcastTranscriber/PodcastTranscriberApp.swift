//
//  PodcastTranscriberApp.swift
//  PodcastTranscriber
//
//  Created by Mullen  Char  on 2026/4/20.
//

import SwiftUI

@main
struct PodcastTranscriberApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
        }
    }
}
