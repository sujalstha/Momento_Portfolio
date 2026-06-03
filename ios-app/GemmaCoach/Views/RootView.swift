// RootView.swift
// Top-level gate. Decides which flow to show based on Supabase auth state and
// onboarding completion:
//   not signed in        → LoginView
//   signed in, new user  → OnboardingView
//   signed in, onboarded → MainTabView (Run / History / Settings)
// Injects the shared stores + the live-coaching engine as environment objects.

import SwiftUI

struct RootView: View {
    @StateObject private var auth = AuthManager()
    @StateObject private var profile = ProfileStore()

    // Live-coaching engine, hoisted to app scope so Home can show watch status
    // and RunSessionView can drive coaching without re-creating the stack.
    @StateObject private var engine = EngineModel()
    @StateObject private var metrics = RunMetricsManager()
    @StateObject private var speaker = CoachSpeaker()
    @StateObject private var liveSession = LiveSession()

    var body: some View {
        Group {
            if auth.session == nil {
                LoginView()
                    .transition(.opacity)
            } else if !profile.hasOnboarded {
                OnboardingView()
                    .transition(.opacity)
            } else if !engine.isModelDownloaded {
                // Screen 2.5 — download the coaching model once, then cache it.
                // Skipped on every later launch/login because the model is on disk.
                DownloadingModelView()
                    .transition(.opacity)
            } else {
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: auth.session?.user.id)
        .animation(.easeInOut(duration: 0.35), value: profile.hasOnboarded)
        .animation(.easeInOut(duration: 0.35), value: engine.isModelDownloaded)
        .environmentObject(auth)
        .environmentObject(profile)
        .environmentObject(engine)
        .environmentObject(metrics)
        .environmentObject(speaker)
        .environmentObject(liveSession)
        .task {
            // Capture the email from the Supabase session into the profile once.
            if let email = auth.userEmail, profile.email != email {
                profile.email = email
            }
            liveSession.attach(engine: engine, speaker: speaker, metrics: metrics)
        }
        .onChange(of: auth.session?.user.id) { _, _ in
            if let email = auth.userEmail { profile.email = email }
        }
    }
}
