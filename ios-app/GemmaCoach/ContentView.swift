// ContentView.swift
// Minimal SwiftUI UI: text + audio + run + show metrics + mirror Watch live.

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var engine: EngineModel
    @StateObject private var metricsManager = RunMetricsManager()
    @StateObject private var speaker = CoachSpeaker()
    @StateObject private var liveSession = LiveSession()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    statusCard
                    metricsCard
                    outputCard
                    watchMirrorCard
                    coachCard
                }
                .padding()
            }
            .navigationTitle("Gemma Coach")
            .task {
                // Prompts the user for HealthKit access on first launch.
                // Without this, the iOS app can't read mirrored sample values
                // even when the Watch's mirroring handshake succeeds.
                await metricsManager.requestAuthorizationIfNeeded()
                liveSession.attach(engine: engine, speaker: speaker, metrics: metricsManager)
            }
            .onChange(of: metricsManager.hasMirroredSession) { _, mirroring in
                if mirroring {
                    liveSession.mirroringDidStart()
                } else {
                    liveSession.mirroringDidStop()
                }
            }
        }
    }

    private var statusCard: some View {
        GroupBox {
            switch engine.status {
            case .idle:
                VStack(alignment: .leading, spacing: 10) {
                    Text("Gemma 4 E2B (~5.4 GB) is not loaded.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button {
                        Task { await engine.loadIfNeeded() }
                    } label: {
                        Label("Download & Load Model", systemImage: "arrow.down.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }
            case .downloading(let p):
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Downloading Gemma 4 E2B")
                        Spacer()
                        Text("\(Int(p * 100))%")
                            .monospacedDigit()
                    }
                    .font(.caption.weight(.medium))
                    ProgressView(value: max(p, 0.005), total: 1.0)
                    if !engine.loadingMessage.isEmpty {
                        Text(engine.loadingMessage)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            case .loading:
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView()
                    if !engine.loadingMessage.isEmpty {
                        Text(engine.loadingMessage)
                            .font(.caption).foregroundStyle(.secondary)
                            .lineLimit(2)
                    } else {
                        Text("Loading model — this may take a few minutes…")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            case .ready: Label("Ready", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            case .generating: ProgressView("Generating…")
            case .error(let msg):
                VStack(alignment: .leading, spacing: 8) {
                    Label(msg, systemImage: "xmark.octagon.fill").foregroundStyle(.red).font(.caption)
                    Button("Retry") { Task { await engine.loadIfNeeded() } }
                        .buttonStyle(.bordered)
                }
            }
        }
    }

    private var metricsCard: some View {
        GroupBox("Last run") {
            HStack(spacing: 16) {
                metric("TTFT", String(format: "%.2f s", engine.lastTimeToFirstToken))
                metric("Decode", String(format: "%.1f tok/s", engine.lastDecodeTokensPerSecond))
                metric("Total", String(format: "%.2f s", engine.lastTotalTime))
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.system(.caption, design: .monospaced))
        }
    }

    private var outputCard: some View {
        GroupBox("Output") {
            Text(engine.output.isEmpty ? "—" : engine.output)
                .font(.system(.callout, design: .default))
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
    }

    // MARK: - Watch mirror (exactly what the Watch shows, 1Hz)

    private var watchMirrorCard: some View {
        GroupBox("Watch Mirror") {
            VStack(alignment: .leading, spacing: 10) {
                mirrorStatusRow

                if metricsManager.hasMirroredSession {
                    mirrorBig(label: "Heart Rate",
                              value: metricsManager.currentHeartRateBPM > 0
                                  ? "\(metricsManager.currentHeartRateBPM)" : "—",
                              unit: "BPM",
                              tint: .red)

                    mirrorBig(label: "Pace",
                              value: metricsManager.formattedPace,
                              unit: "",
                              tint: .green)

                    HStack(spacing: 12) {
                        mirrorSmall("Dist", metricsManager.formattedDistance)
                        mirrorSmall("Cadence",
                                    metricsManager.currentCadenceSPM > 0
                                        ? "\(Int(metricsManager.currentCadenceSPM)) spm" : "—")
                    }
                    HStack(spacing: 12) {
                        mirrorSmall("Power",
                                    metricsManager.currentRunningPowerWatts > 0
                                        ? "\(Int(metricsManager.currentRunningPowerWatts)) W"
                                        : "calibrating…")
                        mirrorSmall("Stride",
                                    metricsManager.currentStrideLengthMeters > 0
                                        ? String(format: "%.2f m", metricsManager.currentStrideLengthMeters)
                                        : "calibrating…")
                    }
                    HStack(spacing: 12) {
                        mirrorSmall("Vert Osc",
                                    metricsManager.currentVerticalOscillationCm > 0
                                        ? String(format: "%.1f cm", metricsManager.currentVerticalOscillationCm)
                                        : "calibrating…")
                        mirrorSmall("Gnd Cont",
                                    metricsManager.currentGroundContactTimeMs > 0
                                        ? "\(Int(metricsManager.currentGroundContactTimeMs)) ms"
                                        : "calibrating…")
                    }
                    HStack(spacing: 12) {
                        mirrorSmall("Elev", String(format: "%.1f m", metricsManager.currentElevationMeters))
                        mirrorSmall("Kcal", String(format: "%.0f", metricsManager.currentCalories))
                    }
                    HStack(spacing: 12) {
                        mirrorSmall("Elapsed", metricsManager.formattedElapsed)
                        mirrorSmall("SpO₂",
                                    metricsManager.currentBloodOxygenPercent > 0
                                        ? String(format: "%.0f%%", metricsManager.currentBloodOxygenPercent)
                                        : "scheduled…")
                    }
                } else {
                    Text("Waiting for Watch — start a workout on your Apple Watch.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - Coach (Gemma + TTS, persona-driven)

    private var coachCard: some View {
        GroupBox("Coach") {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Persona", selection: $liveSession.persona) {
                    ForEach(CoachPersona.allCases) { persona in
                        Text(persona.displayName).tag(persona)
                    }
                }
                .pickerStyle(.segmented)

                coachStatusRow

                if !liveSession.lastCoachingMessage.isEmpty {
                    Text(liveSession.lastCoachingMessage)
                        .font(.callout)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                } else if liveSession.persona == .off {
                    Text("Muted. Pick Concise or Analytical to enable voice coaching.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if !metricsManager.hasMirroredSession {
                    Text("Coach will start automatically when you press Start on the Watch.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if !engine.isReady {
                    Text("Waiting for Gemma to finish loading — coach will speak as soon as it's ready.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Generating first coaching tip…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let err = liveSession.lastError {
                    Text(err)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private var coachStatusRow: some View {
        HStack(spacing: 8) {
            if liveSession.isRunning {
                Image(systemName: speaker.isSpeaking
                      ? "speaker.wave.3.fill"
                      : "brain.head.profile")
                    .foregroundStyle(speaker.isSpeaking ? Color.accentColor : .green)
                Text(speaker.isSpeaking ? "Speaking…" : "Listening for next trigger")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "circle")
                    .foregroundStyle(.secondary)
                Text("Idle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if liveSession.triggerCount > 0 {
                Text("\(liveSession.triggerCount) ticks")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    private var mirrorStatusRow: some View {
        HStack(spacing: 6) {
            Image(systemName: metricsManager.hasMirroredSession
                  ? "applewatch.radiowaves.left.and.right"
                  : "applewatch.slash")
                .imageScale(.medium)
            Text(metricsManager.hasMirroredSession ? "Mirroring · Watch" : "Not mirroring")
                .font(.caption)
            Spacer()
        }
        .foregroundStyle(metricsManager.hasMirroredSession ? Color.green : .secondary)
    }

    private func mirrorBig(label: String, value: String, unit: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 36, weight: .semibold, design: .rounded))
                    .foregroundStyle(tint)
                    .monospacedDigit()
                if !unit.isEmpty {
                    Text(unit).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func mirrorSmall(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.system(.callout, design: .monospaced))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var isReady: Bool { engine.isReady }
}

#Preview {
    ContentView().environmentObject(EngineModel())
}
