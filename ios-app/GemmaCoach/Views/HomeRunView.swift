// HomeRunView.swift
// Screen 3 — Run tab. Greeting, watch-connection pill, last-run line, and a
// single circular Start CTA. Coached runs only. Triple-tap anywhere starts.
// Launches the glass RunSessionView which drives the existing coaching engine.

import SwiftUI
import SwiftData

struct HomeRunView: View {
    @EnvironmentObject var profile: ProfileStore
    @EnvironmentObject var metrics: RunMetricsManager
    @Query(sort: \RunRecord.startedAt, order: .reverse) private var runs: [RunRecord]

    @State private var showRun = false

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.top, DT.Spacing.lg)

            Spacer()

            Button { showRun = true } label: { StartCTA() }
                .buttonStyle(PressableScale())
                .accessibilityLabel("Start coached run")
                .accessibilityHint("Triple-tap anywhere to start.")

            Spacer()

            Text("Triple-tap anywhere to start.")
                .font(.footnote)
                .foregroundStyle(DT.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 8)
        }
        .padding(.horizontal, DT.Spacing.screenH)
        .contentShape(Rectangle())
        .gesture(TapGesture(count: 3).onEnded { showRun = true })
        .fullScreenCover(isPresented: $showRun) { RunSessionView() }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(Date.now.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()).uppercased())
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DT.textTertiary)
                Text("Ready, \(profile.firstName)?")
                    .font(.system(size: 36, weight: .bold))
                    .tracking(-1)
                    .foregroundStyle(DT.textPrimary)
                Text(lastRunLine)
                    .font(.system(size: 16))
                    .foregroundStyle(DT.textSecondary)
                    .padding(.top, 2)
            }
            Spacer()
            Pill(text: metrics.hasMirroredSession ? "Watch on" : "Watch off",
                 showDot: true,
                 dotColor: metrics.hasMirroredSession ? DT.green : DT.textQuat)
                .padding(.top, 6)
        }
    }

    private var lastRunLine: String {
        guard let last = runs.first else { return "Your first run is the best one." }
        let imperial = profile.units.isImperial
        return "Last run was \(last.distanceValue(imperial: imperial)) \(last.distanceUnit(imperial: imperial)), coached."
    }
}

/// Button style: subtle press scale, no glass chrome (the label brings its own).
struct PressableScale: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
