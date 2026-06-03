// LiveSession.swift
// Live coaching loop (perception multi-agent): every periodSeconds, fire a fresh
// inference with the current context — goal + live metrics + telemetry trends +
// optional camera keyframe — stream the spoken coaching cue (parsed from the
// coordinator's <coaching_coordinator> section) to the Cartesia speaker.
//
// Ported from the GemmaCoachv0 OG demo; coordinator hardened with the fork's
// safety layer. Speaks via the Cartesia CoachSpeaker (chunks buffer, flush()
// voices the full cue).

import AVFoundation
import Foundation

struct TelemetrySnapshot: Equatable {
    let time: Date
    let heartRate: Int
    let paceString: String
    let cadence: Double
}

@MainActor
final class LiveSession: ObservableObject {
    @Published var isRunning: Bool = false
    @Published var lastTriggerAt: Date? = nil
    @Published var triggerCount: Int = 0
    @Published var periodSeconds: Double = 15
    @Published var lastFinishedDecodeTokensPerSecond: Double = 0
    @Published var lastError: String? = nil
    /// Most recent full coaching response (UI reads this — name kept in sync with
    /// the Momento RunSessionView).
    @Published var lastCoachingMessage: String = ""

    // Multi-agent + goal state
    @Published var runningGoal: RunningGoal = RunningGoal(type: .general, targetValue: "")
    @Published var lastPerceptionThoughts: String = ""
    @Published var lastTelemetryThoughts: String = ""
    @Published var totalDistanceMeters: Double = 0.0
    @Published var compressionTokenSavings: Int = 0

    private weak var engine: EngineModel?
    private weak var speaker: CoachSpeaker?
    private weak var metrics: RunMetricsManager?
    private weak var formAnalyzer: FormVisionAnalyzer?
    private var loopTask: Task<Void, Never>? = nil
    private var inflight: Task<Void, Never>? = nil
    private var chatHistory: [(role: String, content: String)] = []

    private let agentCoordinator = GemmaAgentCoordinator()
    private var telemetryHistory: [TelemetrySnapshot] = []

    func attach(engine: EngineModel, speaker: CoachSpeaker, metrics: RunMetricsManager,
                formAnalyzer: FormVisionAnalyzer? = nil) {
        self.engine = engine
        self.speaker = speaker
        self.metrics = metrics
        if let formAnalyzer { self.formAnalyzer = formAnalyzer }
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        triggerCount = 0
        lastError = nil
        chatHistory = []
        totalDistanceMeters = 0.0
        telemetryHistory = []
        lastPerceptionThoughts = "Awaiting first perception cycle..."
        lastTelemetryThoughts = "Awaiting first telemetry cycle..."
        compressionTokenSavings = 0
        configureBackgroundAudio()

        loopTask = Task { @MainActor in
            await fireOnce()   // immediate first cue
            while !Task.isCancelled && self.isRunning {
                try? await Task.sleep(for: .seconds(self.periodSeconds))
                if Task.isCancelled || !self.isRunning { break }
                await fireOnce()
            }
        }
    }

    func stop() {
        isRunning = false
        loopTask?.cancel(); loopTask = nil
        inflight?.cancel(); inflight = nil
        speaker?.cancel()
        deactivateBackgroundAudio()
    }

    func resetDistance() { totalDistanceMeters = 0.0 }

    /// Cancel any in-flight coaching so a user voice request takes priority.
    func pauseGemmaWorkForUserRequest() {
        if inflight != nil {
            inflight?.cancel()
            inflight = nil
            if chatHistory.last?.role == "user" { chatHistory.removeLast() }
        }
        speaker?.cancel()
    }

    private func fireOnce() async {
        triggerCount += 1
        let now = Date()

        if isRunning, let metrics = metrics {
            let speed = metrics.currentPaceSecondsPerMeter > 0 ? (1.0 / metrics.currentPaceSecondsPerMeter) : 0.0
            let delta = lastTriggerAt.map { now.timeIntervalSince($0) } ?? 0.0
            totalDistanceMeters += speed * delta
        }
        lastTriggerAt = now

        guard let engine = engine else { return }
        guard engine.canStartBackgroundGeneration else { return }

        if let metrics = metrics {
            let snapshot = TelemetrySnapshot(time: now,
                                             heartRate: metrics.currentHeartRateBPM,
                                             paceString: metrics.formattedPace,
                                             cadence: metrics.currentCadenceSPM)
            telemetryHistory.append(snapshot)
            if telemetryHistory.count > 12 { telemetryHistory.removeFirst() }
        }

        startGeneration(engine: engine)
    }

    private func startGeneration(engine: EngineModel) {
        speaker?.cancel()
        agentCoordinator.reset()

        let metricsStr = metrics?.getCurrentStateString() ?? "No live metrics available."
        let telemetryTrends = makeTelemetryTrendsString()
        let keyframe = formAnalyzer?.consumeKeyframe()
        let formDesc = formAnalyzer?.formSummary ?? ""

        let userContent = makeLiveUserContent(
            metricsText: metricsStr,
            trendsText: telemetryTrends,
            goalText: runningGoal.description,
            sceneText: formDesc,
            hasAttachedKeyframe: keyframe != nil
        )

        let userMessage = chatHistory.isEmpty
            ? "\(GemmaAgentCoordinator.systemPrompt)\n\n\(userContent)"
            : userContent
        chatHistory.append((role: "user", content: userMessage))

        let compressedHistory = agentCoordinator.compressHistory(chatHistory)
        let rawCount = chatHistory.reduce(0) { $0 + $1.content.count }
        let compCount = compressedHistory.reduce(0) { $0 + $1.content.count }
        self.compressionTokenSavings = max(0, (rawCount - compCount) / 4)

        let speaker = self.speaker
        let currentHistory = compressedHistory

        inflight = Task { @MainActor in
            var fullResponse = ""
            let onChunk: @MainActor (String) -> Void = { chunk in
                fullResponse += chunk
                let parsedChunk = self.agentCoordinator.appendAndParse(chunk)
                if !parsedChunk.isEmpty { speaker?.speak(chunk: parsedChunk) }
            }

            if let frame = keyframe {
                await engine.streamCoachVision(history: currentHistory, keyframe: frame,
                                               priority: .background, onChunk: onChunk)
            } else {
                await engine.streamCoach(history: currentHistory, priority: .background, onChunk: onChunk)
            }

            guard !Task.isCancelled else { return }

            if !fullResponse.isEmpty {
                let parsed = self.agentCoordinator.parseFinal()
                self.lastCoachingMessage = parsed.spokenCue.isEmpty ? fullResponse : parsed.spokenCue
                self.lastPerceptionThoughts = parsed.perceptionThoughts.isEmpty ? "No spatial hazards parsed." : parsed.perceptionThoughts
                self.lastTelemetryThoughts = parsed.telemetryThoughts.isEmpty ? "No telemetry insights parsed." : parsed.telemetryThoughts
            }

            self.chatHistory.append((role: "model", content: fullResponse))
            if self.chatHistory.count > 11 {
                self.chatHistory.remove(at: 1)
                self.chatHistory.remove(at: 1)
            }

            speaker?.flush()
            self.lastFinishedDecodeTokensPerSecond = engine.lastDecodeTokensPerSecond
        }
    }

    private func makeTelemetryTrendsString() -> String {
        var trends = "Biometric trends over the last few turns:\n"
        if telemetryHistory.isEmpty {
            trends += "- No trend data available yet.\n"
        } else {
            for snap in telemetryHistory {
                let elapsed = Int(Date().timeIntervalSince(snap.time))
                let hrVal = snap.heartRate > 0 ? "\(snap.heartRate) BPM" : "searching"
                trends += "- \(elapsed)s ago: HR \(hrVal), Pace \(snap.paceString), Cadence \(Int(snap.cadence)) spm\n"
            }
        }
        let miles = totalDistanceMeters / 1609.34
        trends += "\nTotal Run Distance: \(String(format: "%.2f", miles)) miles\n"

        switch runningGoal.type {
        case .distance:
            if let targetDist = Double(runningGoal.targetValue) {
                let remaining = max(0.0, targetDist - miles)
                trends += "Goal Status: Target distance \(targetDist) miles. Completed \(String(format: "%.2f", miles)) miles. Remaining: \(String(format: "%.2f", remaining)) miles.\n"
            }
        case .pace:
            trends += "Goal Status: Target pace \(runningGoal.targetValue) minutes per mile. Current Pace: \(metrics?.formattedPace ?? "Standing still").\n"
        case .heartRate:
            let ceiling = Int(runningGoal.targetValue) ?? 160
            let diff = (metrics?.currentHeartRateBPM ?? 0) - ceiling
            trends += "Goal Status: HR Limit \(ceiling) BPM. Current HR: \(metrics?.currentHeartRateBPM ?? 0) BPM. Limit Diff: \(diff > 0 ? "+\(diff) BPM (EXCEEDED)" : "\(diff) BPM").\n"
        case .general:
            trends += "Goal Status: Maintain safe, steady fitness pacing.\n"
        }
        return trends
    }

    private func makeLiveUserContent(
        metricsText: String, trendsText: String, goalText: String,
        sceneText: String, hasAttachedKeyframe: Bool
    ) -> String {
        let visualState: String
        if sceneText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            visualState = "No new visual hazard signal."
        } else if hasAttachedKeyframe {
            visualState = "\(sceneText)\nA camera keyframe is attached for verification."
        } else {
            visualState = sceneText
        }
        return """
        User's Stated Running Goal:
        \(goalText)

        Raw telemetry:
        \(metricsText)

        \(trendsText)

        Visual context:
        \(visualState)

        Coaching decision:
        Reason through the perception_agent and telemetry_agent sections first, then output the final spoken coaching cue under the coaching_coordinator section.
        Ensure your coaching_coordinator output is an informative, direct spoken instruction.
        """
    }

    // MARK: - Background audio

    private func configureBackgroundAudio() {
        do { try speaker?.activateCoachAudioSession() }
        catch { lastError = "audio session: \(error.localizedDescription)" }
    }

    private func deactivateBackgroundAudio() {
        speaker?.deactivateCoachAudioSession()
    }
}
