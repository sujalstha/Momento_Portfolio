// RunSessionView.swift
// The active coached run, in the Liquid-Glass idiom. Countdown 3-2-1, then it
// starts the existing engine (RunMetricsManager + LiveSession + Gemma + TTS),
// shows live metric tiles and Echo's transcript, and on stop persists a
// RunRecord (SwiftData) + an HKWorkout for phone-only runs.

import SwiftUI
import SwiftData

struct RunSessionView: View {
    @EnvironmentObject var engine: EngineModel
    @EnvironmentObject var metrics: RunMetricsManager
    @EnvironmentObject var speaker: CoachSpeaker
    @EnvironmentObject var liveSession: LiveSession
    @EnvironmentObject var profile: ProfileStore
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var phase: Phase = .countdown
    @State private var countdown = 3
    @State private var startDate = Date()
    @State private var accumulator = MetricAccumulator()
    @State private var ticker: Timer?

    // Perception + voice (run-scoped)
    @StateObject private var formAnalyzer = FormVisionAnalyzer()
    @StateObject private var hazardScanner = LiveVisualHazardScanner()
    @StateObject private var voice = VoiceInputController()
    @State private var isListening = false

    private enum Phase { case countdown, running, finishing }

    var body: some View {
        ZStack {
            Backdrop(style: .dawn)
            switch phase {
            case .countdown:  countdownView
            case .running:    runningView
            case .finishing:  ProgressView("Saving run…").tint(DT.textPrimary)
            }
        }
        .task { await runCountdown() }
        .onDisappear { ticker?.invalidate() }
    }

    // MARK: - Countdown

    private var countdownView: some View {
        VStack(spacing: 12) {
            Text("Get ready").eyebrowStyle()
            Text("\(countdown)")
                .font(.system(size: 120, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(DT.textPrimary)
                .contentTransition(.numericText())
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Starting in \(countdown)")
    }

    private func runCountdown() async {
        speaker.speak("Get ready. Starting your run.")
        for n in stride(from: 3, through: 1, by: -1) {
            countdown = n
            try? await Task.sleep(for: .seconds(1))
        }
        beginRun()
    }

    // MARK: - Running

    private var runningView: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal, DT.Spacing.screenH)
                .padding(.top, 8)

            ScrollView {
                VStack(spacing: DT.Spacing.md) {
                    heroBlock
                    tilesGrid
                    coachCard
                }
                .padding(.horizontal, DT.Spacing.screenH)
                .padding(.bottom, 120)
            }
        }
        .safeAreaInset(edge: .bottom) { stopBar }
    }

    private var topBar: some View {
        HStack {
            Pill(text: metrics.hasMirroredSession ? "Watch" : "Phone",
                 showDot: true,
                 dotColor: metrics.hasMirroredSession ? DT.green : DT.accent)
            Spacer()
            Pill(text: engineStatusText,
                 showDot: true,
                 dotColor: engine.isReady ? DT.green : DT.accent)
        }
    }

    private var heroBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("DISTANCE").font(.system(size: 12, weight: .medium)).foregroundStyle(DT.textTertiary)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(distanceValue)
                    .font(.system(size: 80, weight: .bold))
                    .monospacedDigit()
                    .tracking(-3)
                    .foregroundStyle(DT.textPrimary)
                Text(profile.units.isImperial ? "mi" : "km")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DT.textTertiary)
            }
            Text("\(metrics.formattedElapsed) · \(metrics.formattedPace)")
                .font(.system(size: 16))
                .monospacedDigit()
                .foregroundStyle(DT.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var tilesGrid: some View {
        let cols = [GridItem(.flexible(), spacing: DT.Spacing.md),
                    GridItem(.flexible(), spacing: DT.Spacing.md)]
        return LazyVGrid(columns: cols, spacing: DT.Spacing.md) {
            tile("Heart rate", metrics.currentHeartRateBPM > 0 ? "\(metrics.currentHeartRateBPM)" : "—", "BPM", .red)
            tile("Cadence", metrics.currentCadenceSPM > 0 ? "\(Int(metrics.currentCadenceSPM))" : "—", "SPM", DT.textPrimary)
            tile("Power", metrics.currentRunningPowerWatts > 0 ? "\(Int(metrics.currentRunningPowerWatts))" : "—", "W", DT.textPrimary)
            tile("Stride", metrics.currentStrideLengthMeters > 0 ? String(format: "%.2f", metrics.currentStrideLengthMeters) : "—", "M", DT.textPrimary)
            tile("Cal", metrics.currentCalories > 0 ? "\(Int(metrics.currentCalories))" : "—", "KCAL", DT.textPrimary)
            tile("SpO₂", metrics.currentBloodOxygenPercent > 0 ? "\(Int(metrics.currentBloodOxygenPercent))" : "—", "%", DT.textPrimary)
        }
    }

    private func tile(_ label: String, _ value: String, _ unit: String, _ tint: Color) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 4) {
                Text(label).font(.system(size: 12, weight: .medium)).foregroundStyle(DT.textTertiary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.system(size: 30, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(tint)
                    Text(unit).font(.system(size: 11, weight: .semibold)).foregroundStyle(DT.textTertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(value) \(unit)")
    }

    private var coachCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: speaker.isSpeaking ? "speaker.wave.3.fill" : "brain.head.profile")
                        .foregroundStyle(speaker.isSpeaking ? DT.accent : DT.green)
                    Text(coachStatus).eyebrowStyle()
                }
                Text(liveSession.lastCoachingMessage.isEmpty ? "Echo will check in as you run." : liveSession.lastCoachingMessage)
                    .font(.system(size: 16))
                    .foregroundStyle(DT.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
        }
        .accessibilityElement(children: .combine)
    }

    private var stopBar: some View {
        HStack(spacing: DT.Spacing.md) {
            Button { toggleListening() } label: {
                HStack(spacing: 8) {
                    Image(systemName: isListening ? "waveform" : "mic.fill")
                    Text(isListening ? "Listening…" : "Ask Echo")
                }
            }
            .buttonStyle(GlassButtonStyle(variant: .glass, tint: isListening ? DT.accent : DT.textPrimary))
            .accessibilityLabel(isListening ? "Listening, tap to stop" : "Ask Echo a question")

            Button { Task { await endRun() } } label: {
                HStack(spacing: 8) {
                    Image(systemName: "stop.fill")
                    Text("Finish")
                }
            }
            .buttonStyle(GlassButtonStyle(variant: .glassStrong, tint: DT.vermilion))
            .accessibilityLabel("Finish run")
        }
        .padding(.horizontal, DT.Spacing.screenH)
        .padding(.bottom, 8)
    }

    // MARK: - Engine lifecycle

    private func beginRun() {
        phase = .running
        startDate = Date()
        accumulator = MetricAccumulator()

        // Wire perception: form analyzer feeds keyframes to the coach loop;
        // the hazard scanner owns the camera/depth and speaks urgent warnings.
        liveSession.attach(engine: engine, speaker: speaker, metrics: metrics, formAnalyzer: formAnalyzer)
        hazardScanner.attach(engine: engine, speaker: speaker)

        metrics.start()
        Task { await engine.loadIfNeeded() }
        Task {
            // Camera + LiDAR depth power the YOLO hazard gate (device-only).
            let cameraOK = await AVDepthFrameProvider.requestCameraAccessIfNeeded()
            if cameraOK { hazardScanner.start() }
            liveSession.start()   // coaching runs with or without camera
        }

        ticker = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in accumulator.sample(metrics) }
        }
    }

    // MARK: - Voice command ("talk to the app")

    private func toggleListening() {
        if isListening {
            voice.stopListening()
            isListening = false
            return
        }
        // Stop coaching so the runner's question takes priority.
        liveSession.pauseGemmaWorkForUserRequest()
        isListening = true
        voice.onFinalTranscript = { transcript in
            Task { @MainActor in
                isListening = false
                voice.stopListening()
                await answerRunnerQuestion(transcript)
            }
        }
        Task { await voice.requestAuthorization(); voice.startListening() }
    }

    /// Answer a spoken question, scope-locked to running coaching (RunCoachSafety).
    /// Layer 1 (input screen) → Layer 2/3 (scope-locked model) → Layer 4 (output screen).
    /// Only THIS runner's own live stats are ever placed in the prompt.
    private func answerRunnerQuestion(_ question: String) async {
        switch RunCoachSafety.screenInput(question) {
        case .reject:
            speaker.speak(RunCoachSafety.refusal)
        case .allow(let clean):
            let stats = metrics.getCurrentStateString()
            let command = "Runner asked: \"\(clean)\"\n\nCurrent live stats (this runner only):\n\(stats)"
            if let answer = await engine.generateVoiceAnswerInEnglish(command) {
                speaker.speak(RunCoachSafety.screenOutput(answer))
            } else {
                speaker.speak(RunCoachSafety.refusal)
            }
        }
    }

    private func endRun() async {
        phase = .finishing
        ticker?.invalidate(); ticker = nil
        voice.stopListening()
        hazardScanner.stop()
        liveSession.stop()
        let wasMirrored = metrics.hasMirroredSession
        let elapsed = metrics.currentElapsedSeconds > 0
            ? metrics.currentElapsedSeconds
            : Date().timeIntervalSince(startDate)
        let record = accumulator.makeRecord(distanceMeters: metrics.currentDistanceMeters,
                                            caloriesKcal: Int(metrics.currentCalories),
                                            durationSeconds: elapsed,
                                            startedAt: startDate)
        metrics.stop()

        modelContext.insert(record)
        try? modelContext.save()

        // Snapshot plain values on the main actor BEFORE any background work —
        // never hand the SwiftData model to an async task (thread-confinement crash).
        let distanceMeters = record.distanceMeters
        let calories = record.caloriesKcal
        let duration = record.durationSeconds

        // Leave the run screen immediately; HealthKit save is best-effort and
        // must not block dismissal (auth prompts / stalls froze the screen).
        dismiss()

        if !wasMirrored {
            Task.detached {
                await HealthKitWorkoutSaver.save(distanceMeters: distanceMeters,
                                                 calories: calories,
                                                 durationSeconds: duration)
            }
        }
    }

    // MARK: - Derived display

    private var distanceValue: String {
        let m = metrics.currentDistanceMeters
        return String(format: "%.2f", profile.units.isImperial ? m / 1609.34 : m / 1000)
    }

    private var engineStatusText: String {
        switch engine.status {
        case .idle:             return "Coach idle"
        case .downloading:      return "Downloading"
        case .loading:          return "Loading coach"
        case .ready, .generating: return "Coach ready"
        case .error:            return "Coach error"
        }
    }

    private var coachStatus: String {
        if !engine.isReady { return "Warming up Echo" }
        return speaker.isSpeaking ? "Echo speaking" : "Echo listening"
    }
}

// MARK: - Running-average accumulator

/// Accumulates 1 Hz samples of the instantaneous metrics so we can store
/// run-average summaries in the RunRecord at finish.
struct MetricAccumulator {
    private var hr = Avg(), cadence = Avg(), power = Avg(), stride = Avg()
    private var gct = Avg(), vo = Avg(), spo2 = Avg()
    private var baselineElevation: Double?
    private var maxElevationGain: Double = 0

    private struct Avg {
        var sum = 0.0, count = 0
        mutating func add(_ v: Double) { if v > 0 { sum += v; count += 1 } }
        var value: Double { count > 0 ? sum / Double(count) : 0 }
    }

    @MainActor
    mutating func sample(_ m: RunMetricsManager) {
        hr.add(Double(m.currentHeartRateBPM))
        cadence.add(m.currentCadenceSPM)
        power.add(m.currentRunningPowerWatts)
        stride.add(m.currentStrideLengthMeters)
        gct.add(m.currentGroundContactTimeMs)
        vo.add(m.currentVerticalOscillationCm)
        spo2.add(m.currentBloodOxygenPercent)

        if baselineElevation == nil { baselineElevation = m.currentElevationMeters }
        if let base = baselineElevation {
            maxElevationGain = max(maxElevationGain, m.currentElevationMeters - base)
        }
    }

    func makeRecord(distanceMeters: Double, caloriesKcal: Int,
                    durationSeconds: Double, startedAt: Date) -> RunRecord {
        RunRecord(
            startedAt: startedAt,
            durationSeconds: durationSeconds,
            distanceMeters: distanceMeters,
            isCoached: true,
            avgHeartRateBPM: Int(hr.value.rounded()),
            avgCadenceSPM: Int(cadence.value.rounded()),
            avgPowerWatts: Int(power.value.rounded()),
            avgStrideLengthMeters: (stride.value * 100).rounded() / 100,
            avgGroundContactTimeMs: Int(gct.value.rounded()),
            avgVerticalOscillationCm: (vo.value * 10).rounded() / 10,
            caloriesKcal: caloriesKcal,
            bloodOxygenPercent: Int(spo2.value.rounded()),
            elevationGainMeters: Int(maxElevationGain.rounded())
        )
    }
}
