// GemmaCoachApp.swift
// Momento — on-device Gemma running coach. App entry point: configures Google
// Sign-In, routes auth deep-links (Google + Supabase magic link), provides the
// SwiftData store for run history, and shows the auth-gated RootView.

import SwiftUI
import SwiftData
import GoogleSignIn

@main
struct GemmaCoachApp: App {
    init() {
        // serverClientID makes the Google idToken's audience the Web client that
        // Supabase's Google provider is configured with — so the native sign-in
        // token is accepted without also listing the iOS client ID server-side.
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: AuthSecrets.googleIOSClientID,
            serverClientID: AuthSecrets.googleServerClientID
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .onOpenURL { url in
                    // Google gets first refusal; it returns false for non-Google URLs.
                    if GIDSignIn.sharedInstance.handle(url) { return }
                    // Otherwise treat as the Supabase magic-link callback.
                    Task { try? await supabase.auth.session(from: url) }
                }
        }
        .modelContainer(sharedModelContainer)
    }
}

// MARK: - SwiftData container (with a DEBUG seed for previewable history)

let sharedModelContainer: ModelContainer = {
    let schema = Schema([RunRecord.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
    do {
        let container = try ModelContainer(for: schema, configurations: [config])
        #if DEBUG
        // First access is from the main-actor App scene, so this is safe.
        MainActor.assumeIsolated { seedIfEmpty(container) }
        #endif
        return container
    } catch {
        fatalError("Could not create ModelContainer: \(error)")
    }
}()

#if DEBUG
/// Inserts two sample coached runs (matching the design mockup) the first time
/// the store is empty, so History + Metric detail are reviewable on simulator
/// without real sensor hardware. Removed automatically once real runs exist.
@MainActor private func seedIfEmpty(_ container: ModelContainer) {
    let ctx = container.mainContext
    let count = (try? ctx.fetchCount(FetchDescriptor<RunRecord>())) ?? 0
    guard count == 0 else { return }

    let cal = Calendar.current
    let yesterday = cal.date(byAdding: .day, value: -1, to: .now) ?? .now
    let earlier = cal.date(byAdding: .day, value: -4, to: .now) ?? .now

    ctx.insert(RunRecord(
        startedAt: yesterday, durationSeconds: 34 * 60 + 12, distanceMeters: 4200,
        avgHeartRateBPM: 152, avgCadenceSPM: 168, avgPowerWatts: 241,
        avgStrideLengthMeters: 1.14, avgGroundContactTimeMs: 242,
        avgVerticalOscillationCm: 8.1, caloriesKcal: 312,
        bloodOxygenPercent: 97, elevationGainMeters: 38))

    ctx.insert(RunRecord(
        startedAt: earlier, durationSeconds: 41 * 60 + 50, distanceMeters: 5000,
        avgHeartRateBPM: 148, avgCadenceSPM: 166, avgPowerWatts: 236,
        avgStrideLengthMeters: 1.12, avgGroundContactTimeMs: 248,
        avgVerticalOscillationCm: 8.4, caloriesKcal: 365,
        bloodOxygenPercent: 98, elevationGainMeters: 22))

    try? ctx.save()
}
#endif
