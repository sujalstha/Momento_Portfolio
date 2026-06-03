// GemmaCoachWatchApp.swift — Watch app entry point.

import SwiftUI

@main
struct GemmaCoachWatchApp: App {
    @StateObject private var workout = WorkoutManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(workout)
        }
    }
}
