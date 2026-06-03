import CoreGraphics
import Foundation
import UIKit

struct HazardScanEvent: Identifiable, Equatable {
    let id = UUID()
    let time: Date
    let candidateID: String
    let nearestDepthMeters: Float?
    let hazardLabel: String
    let hazardScore: Float
    let safeLabel: String
    let safeScore: Float
    let margin: Float
    let reason: String
    let sentToGemma: Bool
    let gemmaResult: String?
    let spoken: Bool
    let reviewKind: String

    var depthSummary: String {
        nearestDepthMeters.map { String(format: "%.2f m", $0) } ?? "unknown"
    }

    var summary: String {
        let action = spoken ? "spoke" : sentToGemma ? "verified" : "skipped"
        let result = gemmaResult.map { " \($0)" } ?? ""
        return "\(reviewKind) \(action) \(candidateID) \(depthSummary) margin \(String(format: "%.3f", margin)) \(reason)\(result)"
    }
}

private enum HazardRiskLevel: String {
    case clear
    case caution
    case warning
    case urgent
}

private struct HazardRiskAssessment {
    let level: HazardRiskLevel
    let closestDepthMeters: Float?
    let routePosition: String
    let nearDepthPixelRatio: Float
    let closeDepthPixelRatio: Float
    let candidateAreaRatio: Float
    let ruleSummary: String
    let fallbackWarning: String?

    var shouldOverrideClear: Bool {
        level == .warning || level == .urgent
    }

    var shouldSpeakImmediately: Bool {
        level == .urgent
    }
}

private struct HazardFrameBurst {
    var decision: HazardGateDecision
    var frames: [DepthCameraFrame]
    var futureFramesNeeded: Int
    let startedAt: Date
    let highlightBox: CGRect?
    let candidate: DepthCandidate?
    let risk: HazardRiskAssessment
    let preSpokenWarning: String?

    var isReady: Bool {
        futureFramesNeeded <= 0 || frames.count >= 5 || Date().timeIntervalSince(startedAt) >= 2.5
    }
}

enum HazardVerificationText {
    static func cleanedVerificationResponse(_ response: String, candidateID: String? = nil) -> String {
        var compact = response
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        compact = compact.trimmingCharacters(in: CharacterSet(charactersIn: "-* \"'"))
        if compact.lowercased().hasPrefix("clear") {
            return "Clear"
        }
        compact = stripWeakLanguagePrefix(compact)

        let sentence: String
        if let sentenceEnd = compact.firstIndex(where: { ".!?".contains($0) }) {
            sentence = String(compact[...sentenceEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            sentence = compact
        }

        guard isActionableAlert(sentence) else { return "Clear" }
        let actionSentence = ensureActionVerb(sentence)
        guard let candidateID else { return ensureTerminalPunctuation(actionSentence) }
        return ensureDirection(actionSentence, candidateID: candidateID)
    }

    static func isActionableAlert(_ response: String) -> Bool {
        let normalized = response
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".!"))
            .lowercased()
        guard !normalized.isEmpty else { return false }

        // Explicit non-alert phrases only — don't filter on sentence structure
        let nonAlerts = [
            "clear", "no hazard", "no hazards", "no immediate hazard",
            "path is clear", "all clear", "route is clear", "way is clear"
        ]
        if nonAlerts.contains(where: { normalized == $0 || normalized.hasPrefix($0 + " ") }) {
            return false
        }

        // Filter only definitive meta-noise (model talking about itself or the system)
        let metaNoise = ["yolo", "mobileclip", "contact sheet", "i cannot", "i'm unable", "as an ai"]
        return !metaNoise.contains(where: { normalized.contains($0) })
    }

    static func focusRegionDescription(for candidateID: String) -> String {
        switch candidateID {
        case "full_frame":
            return "entire frame"
        case "ground_near":
            return "lower center ground immediately ahead"
        case "center_path":
            return "center of the path ahead"
        case "left_path":
            return "left side of the path ahead"
        case "right_path":
            return "right side of the path ahead"
        default:
            return tileDescription(for: candidateID) ?? "candidate crop \(candidateID)"
        }
    }

    static func directionDescription(for candidateID: String) -> String {
        switch candidateID {
        case "full_frame":
            return "ahead"
        case "ground_near":
            return "low center ahead"
        case "center_path":
            return "center ahead"
        case "left_path":
            return "left ahead"
        case "right_path":
            return "right ahead"
        default:
            return tileDirection(for: candidateID) ?? "ahead"
        }
    }

    private static func ensureDirection(_ sentence: String, candidateID: String) -> String {
        let direction = directionDescription(for: candidateID)
        let normalized = sentence.lowercased()
        if normalized.contains(direction.lowercased()) {
            return ensureTerminalPunctuation(sentence)
        }

        let base = stripTerminalPunctuation(sentence)
        return "\(capitalizedFirst(direction)), \(lowercaseFirst(base))."
    }

    private static func ensureActionVerb(_ sentence: String) -> String {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.lowercased()
        let actionPrefixes = [
            "avoid ", "step ", "move ", "slow ", "watch ", "stop ",
            "veer ", "go ", "keep ", "prepare ", "lift ", "turn "
        ]
        if actionPrefixes.contains(where: { normalized.hasPrefix($0) }) {
            return ensureTerminalPunctuation(trimmed)
        }
        return "Avoid \(lowercaseFirst(stripTerminalPunctuation(trimmed)))."
    }

    private static func ensureTerminalPunctuation(_ sentence: String) -> String {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = trimmed.last, ".!?".contains(last) else {
            return "\(trimmed)."
        }
        return trimmed
    }

    private static func stripTerminalPunctuation(_ sentence: String) -> String {
        sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".!?"))
    }

    private static func lowercaseFirst(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.lowercased() + text.dropFirst()
    }

    private static func capitalizedFirst(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.uppercased() + text.dropFirst()
    }

    private static func stripWeakLanguagePrefix(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefixes = [
            "maybe ", "possibly ", "probably ", "it looks like ", "looks like ",
            "appears to be ", "seems to be ", "i see ", "i can see ",
            "there is ", "there are "
        ]

        var didStrip = true
        while didStrip {
            didStrip = false
            let normalized = result.lowercased()
            for prefix in prefixes where normalized.hasPrefix(prefix) {
                result = String(result.dropFirst(prefix.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                didStrip = true
                break
            }
        }
        return result
    }

    private static func tileDescription(for candidateID: String) -> String? {
        let parts = candidateID.split(separator: "_")
        guard parts.count == 3,
              parts[0] == "tile",
              let row = Int(parts[1]),
              let col = Int(parts[2]),
              (0..<4).contains(row),
              (0..<4).contains(col) else {
            return nil
        }

        let vertical = ["upper", "upper middle", "lower middle", "lower"][row]
        let horizontal = ["left", "center left", "center right", "right"][col]
        return "\(vertical) \(horizontal) part of the frame"
    }

    private static func tileDirection(for candidateID: String) -> String? {
        let parts = candidateID.split(separator: "_")
        guard parts.count == 3,
              parts[0] == "tile",
              let row = Int(parts[1]),
              let col = Int(parts[2]),
              (0..<4).contains(row),
              (0..<4).contains(col) else {
            return nil
        }

        let distance = ["far", "far", "mid", "near"][row]
        let horizontal = ["left", "slightly left", "slightly right", "right"][col]
        return "\(distance) \(horizontal) ahead"
    }
}

@MainActor
final class LiveVisualHazardScanner: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var isScanning = false
    @Published private(set) var lastDecision: HazardGateDecision? = nil
    @Published private(set) var lastError: String? = nil
    @Published private(set) var framesSeen = 0
    @Published private(set) var skippedByGate = 0
    @Published private(set) var gemmaCalls = 0
    @Published private(set) var backgroundGemmaCalls = 0
    @Published private(set) var spokenAlerts = 0
    @Published private(set) var engineBusySkips = 0
    @Published private(set) var sustainedHazardUntil: Date? = nil
    @Published private(set) var recentEvents: [HazardScanEvent] = []
    @Published var scanIntervalSeconds: Double = 1.0

    let camera = AVDepthFrameProvider()

    private weak var engine: EngineModel?
    private weak var speaker: CoachSpeaker?
    private var loopTask: Task<Void, Never>? = nil
    private var gemmaTask: Task<Void, Never>? = nil
    private var backgroundGemmaTask: Task<Void, Never>? = nil
    private var lastHazardReviewStartedAt: Date? = nil
    private var lastBackgroundFrameAttemptAt: Date? = nil
    private var lastImmediateDepthAlertAt: Date? = nil
    private var recentFrames: [DepthCameraFrame] = []
    private var pendingHazardBurst: HazardFrameBurst? = nil
    private var userVoiceControlPriorityDepth = 0
    private var deferredImmediateDepthWarning: DeferredImmediateDepthWarning? = nil
    private let maximumRecentEvents = 8
    private let maximumRecentFrames = 5
    private let hazardFlagHoldSeconds: TimeInterval = 2
    private let hazardReviewCooldownSeconds: TimeInterval = 3
    private let backgroundFrameIntervalSeconds: TimeInterval = 1.0
    private let hazardBurstFrameIntervalSeconds: TimeInterval = 0.15
    private let immediateDepthAlertCooldownSeconds: TimeInterval = 3.0
    private let deferredImmediateDepthWarningMaxAgeSeconds: TimeInterval = 5.0

    private struct DeferredImmediateDepthWarning {
        let warning: String
        let decision: HazardGateDecision
        let createdAt: Date
    }

    func attach(engine: EngineModel, speaker: CoachSpeaker) {
        self.engine = engine
        self.speaker = speaker
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        lastError = nil
        lastDecision = nil
        framesSeen = 0
        skippedByGate = 0
        gemmaCalls = 0
        backgroundGemmaCalls = 0
        spokenAlerts = 0
        engineBusySkips = 0
        sustainedHazardUntil = nil
        recentEvents = []
        recentFrames = []
        pendingHazardBurst = nil
        deferredImmediateDepthWarning = nil
        userVoiceControlPriorityDepth = 0
        lastHazardReviewStartedAt = nil
        lastBackgroundFrameAttemptAt = nil
        lastImmediateDepthAlertAt = nil
        camera.start()

        loopTask = Task { @MainActor in
            while !Task.isCancelled && self.isRunning {
                await self.scanOnce()
                let delay = self.pendingHazardBurst == nil ? self.scanIntervalSeconds : self.hazardBurstFrameIntervalSeconds
                try? await Task.sleep(for: .seconds(delay))
            }
        }
    }

    func stop() {
        isRunning = false
        loopTask?.cancel()
        loopTask = nil
        gemmaTask?.cancel()
        gemmaTask = nil
        backgroundGemmaTask?.cancel()
        backgroundGemmaTask = nil
        deferredImmediateDepthWarning = nil
        userVoiceControlPriorityDepth = 0
        camera.stop()
        isScanning = false
    }

    func beginUserVoiceControlPriority() {
        userVoiceControlPriorityDepth += 1
    }

    func endUserVoiceControlPriority() {
        userVoiceControlPriorityDepth = max(0, userVoiceControlPriorityDepth - 1)
        speakDeferredImmediateDepthWarningIfAllowed(now: Date())
    }

    func pauseGemmaWorkForUserRequest() {
        gemmaTask?.cancel()
        gemmaTask = nil
        backgroundGemmaTask?.cancel()
        backgroundGemmaTask = nil
    }

    func scanOnce() async {
        guard !isScanning else { return }
        guard let engine else {
            lastError = "Engine is not attached."
            return
        }
        guard let frame = camera.consumeLatestFrame() else {
            lastError = camera.lastError ?? "Waiting for a depth camera frame."
            return
        }

        isScanning = true
        framesSeen += 1
        lastError = nil
        defer { isScanning = false }
        refreshSustainedHazard(now: frame.capturedAt)
        speakDeferredImmediateDepthWarningIfAllowed(now: frame.capturedAt)
        appendRecentFrame(frame)
        appendFrameToPendingBurst(frame)

        if await sendPendingHazardReviewIfReady(now: frame.capturedAt, engine: engine) {
            return
        }
        if pendingHazardBurst != nil {
            return
        }

        guard frame.depthSnapshot != nil || !frame.depthCandidates.isEmpty else {
            skippedByGate += 1
            lastError = "No depth snapshot for localized obstacle check."
            await maybeSendBackgroundFrame(frame, engine: engine)
            return
        }

        do {
            let decision = try await engine.evaluateHazardGate(
                image: frame.image,
                depthSnapshot: frame.depthSnapshot
            )
            lastDecision = decision

            guard shouldStartHazardReview(decision) else {
                skippedByGate += 1
                recordEvent(decision: decision, gemmaResult: nil, spoken: false, reviewKind: "gate")
                await maybeSendBackgroundFrame(frame, engine: engine)
                return
            }

            startOrExtendHazardReview(decision: decision, frame: frame)
            _ = await sendPendingHazardReviewIfReady(now: frame.capturedAt, engine: engine)
        } catch {
            skippedByGate += 1
            lastError = error.localizedDescription
            await maybeSendBackgroundFrame(frame, engine: engine)
        }
    }

    private func shouldStartHazardReview(_ decision: HazardGateDecision) -> Bool {
        decision.shouldSendToGemma
    }

    private func refreshSustainedHazard(now: Date) {
        guard let until = sustainedHazardUntil, now >= until else { return }
        sustainedHazardUntil = nil
    }

    private func appendRecentFrame(_ frame: DepthCameraFrame) {
        recentFrames.append(frame)
        if recentFrames.count > maximumRecentFrames {
            recentFrames.removeFirst(recentFrames.count - maximumRecentFrames)
        }
    }

    private func appendFrameToPendingBurst(_ frame: DepthCameraFrame) {
        guard var burst = pendingHazardBurst else { return }
        if burst.frames.last?.capturedAt != frame.capturedAt {
            burst.frames.append(frame)
            burst.futureFramesNeeded = max(0, burst.futureFramesNeeded - 1)
            if burst.frames.count > 5 {
                burst.frames = Array(burst.frames.suffix(5))
            }
            pendingHazardBurst = burst
        }
    }

    private func startOrExtendHazardReview(decision: HazardGateDecision, frame: DepthCameraFrame) {
        let until = frame.capturedAt.addingTimeInterval(hazardFlagHoldSeconds)
        if sustainedHazardUntil.map({ $0 < until }) ?? true {
            sustainedHazardUntil = until
        }

        backgroundGemmaTask?.cancel()
        backgroundGemmaTask = nil

        if pendingHazardBurst != nil {
            return
        }

        if let lastHazardReviewStartedAt,
           frame.capturedAt.timeIntervalSince(lastHazardReviewStartedAt) < hazardReviewCooldownSeconds {
            recordEvent(decision: decision, gemmaResult: "Sustained review active", spoken: false, reviewKind: "hazard")
            return
        }

        let previousFrames = recentFrames
            .dropLast()
            .suffix(2)
        let candidate = makeLocalizedDecisionCandidate(from: decision)
            ?? frame.depthCandidates.first { $0.id == decision.candidateID }
        let risk = assessRisk(decision: decision, candidate: candidate)
        let preSpokenWarning = speakImmediateDepthWarningIfNeeded(risk, decision: decision, at: frame.capturedAt)

        pendingHazardBurst = HazardFrameBurst(
            decision: decision,
            frames: Array(previousFrames) + [frame],
            futureFramesNeeded: 2,
            startedAt: frame.capturedAt,
            highlightBox: decision.normalizedBox ?? candidate?.normalizedBox,
            candidate: candidate,
            risk: risk,
            preSpokenWarning: preSpokenWarning
        )
    }

    private func assessRisk(decision: HazardGateDecision, candidate: DepthCandidate?) -> HazardRiskAssessment {
        let closestDepth = candidate?.nearestDepthMeters
            ?? decision.nearestDepthMeters
            ?? candidate?.medianDepthMeters
            ?? decision.medianDepthMeters
        let routePosition = Self.routePosition(for: decision.candidateID)
        let nearRatio = candidate?.nearDepthPixelRatio ?? decision.nearDepthPixelRatio
        let closeRatio = candidate?.closeDepthPixelRatio ?? decision.closeDepthPixelRatio
        let veryCloseRatio = candidate?.veryCloseDepthPixelRatio ?? decision.veryCloseDepthPixelRatio
        let areaRatio = candidate?.normalizedAreaRatio
            ?? decision.normalizedBox.map { Float($0.width * $0.height) }
            ?? 0
        let largeNearObject = nearRatio >= 0.18 || closeRatio >= 0.08 || veryCloseRatio >= 0.03
        let isDirectRoute = routePosition == "direct path"

        let level: HazardRiskLevel
        if let closestDepth {
            switch closestDepth {
            case 1.5...:
                level = .clear
            case ..<0.5:
                level = isDirectRoute || largeNearObject ? .urgent : .warning
            case ..<1.0:
                level = isDirectRoute || largeNearObject ? .warning : .caution
            default:
                level = isDirectRoute || largeNearObject ? .warning : .caution
            }
        } else {
            level = decision.shouldSendToGemma ? .warning : .caution
        }

        let ruleSummary: String
        switch level {
        case .urgent:
            ruleSummary = "URGENT: localized depth places the detected object inside the 1.5 m safety envelope; Clear is unsafe unless it is definitely outside the travel lane."
        case .warning:
            ruleSummary = "WARNING: localized depth places the detected object inside the 1.5 m safety envelope; Clear is unsafe unless the path center is visibly open."
        case .caution:
            ruleSummary = "CAUTION: detected object is under 1.5 m but small, side-biased, or ambiguous; Clear is allowed only if it is not in the travel lane."
        case .clear:
            ruleSummary = "CLEAR: localized object depth is at least 1.5 m, unavailable, or outside the route envelope."
        }

        return HazardRiskAssessment(
            level: level,
            closestDepthMeters: closestDepth,
            routePosition: routePosition,
            nearDepthPixelRatio: nearRatio,
            closeDepthPixelRatio: closeRatio,
            candidateAreaRatio: areaRatio,
            ruleSummary: ruleSummary,
            fallbackWarning: Self.fallbackWarning(
                level: level,
                visualCue: decision.topHazard.label,
                direction: HazardVerificationText.directionDescription(for: decision.candidateID)
            )
        )
    }

    private func makeLocalizedDecisionCandidate(from decision: HazardGateDecision) -> DepthCandidate? {
        guard let normalizedBox = decision.normalizedBox else { return nil }
        return DepthCandidate(
            id: decision.candidateID,
            normalizedBox: normalizedBox,
            nearestDepthMeters: decision.nearestDepthMeters,
            medianDepthMeters: decision.medianDepthMeters,
            depthConfidence: decision.depthConfidence,
            validDepthPixelRatio: decision.validDepthPixelRatio,
            nearDepthPixelRatio: decision.nearDepthPixelRatio,
            closeDepthPixelRatio: decision.closeDepthPixelRatio,
            veryCloseDepthPixelRatio: decision.veryCloseDepthPixelRatio
        )
    }

    private func speakImmediateDepthWarningIfNeeded(
        _ risk: HazardRiskAssessment,
        decision: HazardGateDecision,
        at now: Date
    ) -> String? {
        guard risk.shouldSpeakImmediately, let warning = risk.fallbackWarning else { return nil }
        guard lastImmediateDepthAlertAt.map({ now.timeIntervalSince($0) >= immediateDepthAlertCooldownSeconds }) ?? true else {
            return nil
        }
        guard let speaker else { return nil }

        if userVoiceControlPriorityDepth > 0 {
            deferredImmediateDepthWarning = DeferredImmediateDepthWarning(
                warning: warning,
                decision: decision,
                createdAt: now
            )
            recordEvent(decision: decision, gemmaResult: "Deferred immediate \(warning)", spoken: false, reviewKind: "depth")
            return warning
        }

        lastImmediateDepthAlertAt = now
        spokenAlerts += 1
        speaker.speak(warning)
        speaker.flush()
        recordEvent(decision: decision, gemmaResult: "Immediate \(warning)", spoken: true, reviewKind: "depth")
        return warning
    }

    private func speakDeferredImmediateDepthWarningIfAllowed(now: Date) {
        guard userVoiceControlPriorityDepth == 0,
              isRunning,
              let deferred = deferredImmediateDepthWarning
        else { return }

        deferredImmediateDepthWarning = nil

        guard now.timeIntervalSince(deferred.createdAt) <= deferredImmediateDepthWarningMaxAgeSeconds,
              let speaker
        else { return }

        lastImmediateDepthAlertAt = now
        spokenAlerts += 1
        speaker.speak(deferred.warning)
        speaker.flush()
        recordEvent(decision: deferred.decision, gemmaResult: "Deferred immediate \(deferred.warning)", spoken: true, reviewKind: "depth")
    }

    private func finalHazardResponse(_ gemmaResponse: String, risk: HazardRiskAssessment) -> String {
        guard gemmaResponse == "Clear",
              risk.shouldOverrideClear,
              let fallbackWarning = risk.fallbackWarning else {
            return gemmaResponse
        }
        return fallbackWarning
    }

    private static func routePosition(for candidateID: String) -> String {
        switch candidateID {
        case "ground_near", "center_path":
            return "direct path"
        case "left_path", "right_path":
            return "side path"
        case "full_frame":
            return "full frame"
        default:
            guard let tile = tileCoordinates(for: candidateID) else { return "unknown route" }
            if tile.row >= 2 && (tile.col == 1 || tile.col == 2) {
                return "direct path"
            }
            if tile.row >= 2 {
                return "side path"
            }
            return "upper or far field"
        }
    }

    private static func fallbackWarning(
        level: HazardRiskLevel,
        visualCue: String,
        direction: String
    ) -> String? {
        guard level == .warning || level == .urgent else { return nil }
        let object = objectPhrase(from: visualCue)
        let verb = level == .urgent ? "Stop" : "Watch out"
        return "\(verb) - \(object) \(direction)!"
    }

    private static func objectPhrase(from visualCue: String) -> String {
        let label = visualCue.lowercased()
        if label.contains("person") || label.contains("vehicle") {
            return "person or vehicle"
        }
        if label.contains("sign") || label.contains("post") || label.contains("barrier") {
            return "sign or barrier"
        }
        if label.contains("bicycle") || label.contains("scooter") {
            return "bicycle or scooter"
        }
        if label.contains("low obstacle") {
            return "low obstacle"
        }
        if label.contains("hole") {
            return "hole"
        }
        if label.contains("wet") {
            return "wet floor"
        }
        if label.contains("surface") || label.contains("edge") || label.contains("uneven") || label.contains("damaged") {
            return "surface change"
        }
        return "obstacle"
    }

    private static func tileCoordinates(for candidateID: String) -> (row: Int, col: Int)? {
        let parts = candidateID.split(separator: "_")
        guard parts.count == 3,
              parts[0] == "tile",
              let row = Int(parts[1]),
              let col = Int(parts[2]),
              (0..<4).contains(row),
              (0..<4).contains(col) else {
            return nil
        }
        return (row, col)
    }

    private func sendPendingHazardReviewIfReady(now: Date, engine: EngineModel) async -> Bool {
        guard let burst = pendingHazardBurst, burst.isReady else { return false }

        guard engine.isModelLoaded else {
            skippedByGate += 1
            engineBusySkips += 1
            lastError = "Gemma is not ready for a sustained hazard review."
            recordEvent(decision: burst.decision, gemmaResult: "Gemma busy", spoken: false, reviewKind: "hazard")
            return true
        }

        let frames = Self.paddedFiveFrameBurst(burst.frames)
        let contactSheet = Self.makeFiveFrameContactSheet(frames: frames, highlightBox: burst.highlightBox)
        let keyframe = contactSheet ?? burst.frames.last?.image
        guard let keyframe else {
            pendingHazardBurst = nil
            return false
        }

        pendingHazardBurst = nil
        lastHazardReviewStartedAt = now
        gemmaCalls += 1
        let speaker = self.speaker
        let prompt = makeHazardBurstPrompt(
            from: burst.decision,
            candidate: burst.candidate,
            risk: burst.risk,
            frameCount: frames.count
        )
        gemmaTask = Task { @MainActor in
            var response = ""
            await engine.streamCoachVision(
                history: [("user", prompt)],
                keyframe: keyframe,
                priority: .safety,
                onChunk: { chunk in response += chunk }
            )
            guard !Task.isCancelled else { return }
            let cleaned = HazardVerificationText.cleanedVerificationResponse(response, candidateID: burst.decision.candidateID)
            let finalResponse = finalHazardResponse(cleaned, risk: burst.risk)
            let actionable = HazardVerificationText.isActionableAlert(finalResponse)
            let shouldSpeak = actionable && burst.preSpokenWarning == nil
            if shouldSpeak {
                spokenAlerts += 1
                speaker?.speak(finalResponse)
                speaker?.flush()
            }
            let eventResult = cleaned == finalResponse ? cleaned : "\(cleaned) -> \(finalResponse)"
            recordEvent(decision: burst.decision, gemmaResult: eventResult, spoken: shouldSpeak, reviewKind: "hazard")
        }
        return true
    }

    private func maybeSendBackgroundFrame(_ frame: DepthCameraFrame, engine: EngineModel) async {
        guard !isSustainedHazardActive(at: frame.capturedAt), pendingHazardBurst == nil else { return }
        guard lastBackgroundFrameAttemptAt.map({ frame.capturedAt.timeIntervalSince($0) >= backgroundFrameIntervalSeconds }) ?? true else {
            return
        }
        lastBackgroundFrameAttemptAt = frame.capturedAt
        guard engine.canStartBackgroundGeneration else { return }

        backgroundGemmaCalls += 1
        let prompt = makeBackgroundContextPrompt()
        // Background scan is silent — builds Gemma's situational awareness only.
        backgroundGemmaTask = Task { @MainActor in
            var response = ""
            await engine.streamCoachVision(
                history: [("user", prompt)],
                keyframe: frame.image,
                priority: .background,
                onChunk: { chunk in response += chunk }
            )
            guard !Task.isCancelled else { return }
            let cleaned = HazardVerificationText.cleanedVerificationResponse(response, candidateID: "full_frame")
            let decision = HazardGateDecision(
                shouldSendToGemma: false,
                confidence: 0,
                hazardScore: 0,
                safeScore: 0,
                margin: 0,
                topHazard: HazardGateLabelScore(label: "background", score: 0),
                topSafe: HazardGateLabelScore(label: "not_used", score: 0),
                candidateID: "full_frame",
                nearestDepthMeters: frame.depthCandidates.compactMap(\.nearestDepthMeters).min(),
                medianDepthMeters: nil,
                depthConfidence: nil,
                validDepthPixelRatio: 0,
                nearDepthPixelRatio: 0,
                closeDepthPixelRatio: 0,
                veryCloseDepthPixelRatio: 0,
                normalizedBox: nil,
                reason: "background_context_1fps",
                elapsedMs: 0
            )
            recordEvent(decision: decision, gemmaResult: cleaned, spoken: false, reviewKind: "background")
        }
    }

    private func isSustainedHazardActive(at now: Date) -> Bool {
        sustainedHazardUntil.map { now < $0 } ?? false
    }

    private func makeHazardBurstPrompt(
        from decision: HazardGateDecision,
        candidate: DepthCandidate?,
        risk: HazardRiskAssessment,
        frameCount: Int
    ) -> String {
        let nearestDepth = decision.nearestDepthMeters.map { String(format: "%.2f m", $0) } ?? "unknown"
        let medianDepth = decision.medianDepthMeters.map { String(format: "%.2f m", $0) } ?? "unknown"
        let depthConfidence = decision.depthConfidence.map { String(format: "%.0f%%", $0 * 100) } ?? "unknown"
        let focusRegion = HazardVerificationText.focusRegionDescription(for: decision.candidateID)
        let direction = HazardVerificationText.directionDescription(for: decision.candidateID)
        let riskDepth = risk.closestDepthMeters.map { String(format: "%.2f m", $0) } ?? "unknown"
        let nearCoverage = String(format: "%.0f%%", risk.nearDepthPixelRatio * 100)
        let closeCoverage = String(format: "%.0f%%", risk.closeDepthPixelRatio * 100)
        let candidateArea = String(format: "%.0f%%", risk.candidateAreaRatio * 100)
        let validCoverage = candidate.map { String(format: "%.0f%%", $0.validDepthPixelRatio * 100) } ?? "unknown"
        let gateEvidence: String
        if decision.reason.hasPrefix("depth_only") {
            gateEvidence = """
            - Depth cue: broad unclassified close surface in the center path (\(decision.topHazard.text))
            - Treat this as obstacle-depth evidence, not as an object class. Verify whether the center path is blocked by a wall, door, fence, post, person, or other surface.
            """
        } else {
            gateEvidence = """
            - YOLO detection: \(decision.topHazard.label) at \(String(format: "%.0f%%", decision.confidence * 100)) confidence (\(decision.topHazard.text))
            - Treat YOLO as object-box evidence only; verify whether this object is truly in the runner's travel lane.
            """
        }

        let depthRule: String
        if let nearest = risk.closestDepthMeters {
            switch nearest {
            case ..<0.5:
                depthRule = "Nearest object is UNDER 0.5 m — extremely urgent, start with 'Stop' or 'Move now'."
            case 0.5..<1.0:
                depthRule = "Nearest object is \(riskDepth) — very close, start with 'Watch out' or 'Avoid'."
            case 1.0..<1.5:
                depthRule = "Nearest object is \(riskDepth) — close, use urgent tone."
            default:
                depthRule = "Nearest object is \(riskDepth) — beyond 1.5 m, output exactly: Clear"
            }
        } else {
            depthRule = "Depth unknown — assess from the frames directly."
        }

        return """
        You are a safety spotter for a runner. Study the five-frame contact sheet (left-to-right, top-to-bottom: prev 2 → detection → next 2).

        Step 1 — Read the full scene: What is the overall environment? (sidewalk, road, trail, indoor, etc.) Where are the edges of the path? What large objects or people are present anywhere in the frame?

        Step 2 — Locate the specific hazard candidate:
        - Focus region: \(focusRegion)
        - Route position: \(risk.routePosition)
        - Depth: nearest \(nearestDepth), median \(medianDepth) (confidence \(depthConfidence))
        - Candidate size: box covers \(candidateArea) of frame; valid depth covers \(validCoverage) of candidate; depth under 1.5 m covers \(nearCoverage); depth under 1 m covers \(closeCoverage)
        \(gateEvidence)

        Step 3 — Apply this risk floor:
        - \(risk.ruleSummary)
        - \(depthRule)
        - Direction phrase to use in any warning: \(direction)

        Step 4 — Output ONLY one of:
        A) Exactly the word: Clear
        B) A short spoken warning under 12 words using this pattern: "Watch out - [what it is] [direction]!"
           Examples: "Watch out - pothole center ahead!", "Watch out - person stepping left ahead!", "Move right - curb drop ahead!"

        Do not dismiss the marked candidate if it is in the runner's lane and under 1.5 m.
        Output Clear only if no marked object is in the center travel lane within about 1.5 m, or the marked object is clearly beside the path.
        Ignore things beside the path or in the background.
        Do not output anything except "Clear" or the warning sentence. No explanations, no scores, no depth numbers, no mention of frames or images.
        """
    }

    private func makeBackgroundContextPrompt() -> String {
        """
        You are a silent scene monitor for a runner. A live camera frame is attached.
        Describe the running environment in one short sentence: surface type, path width, any objects present and their location. This is for internal context only — the runner will not hear it.
        Output format: one plain descriptive sentence, no warnings, no action verbs, no mention of hazards.
        """
    }

    private static func paddedFiveFrameBurst(_ frames: [DepthCameraFrame]) -> [DepthCameraFrame] {
        guard let first = frames.first else { return [] }
        var padded = frames
        while padded.count < 5 {
            padded.append(padded.last ?? first)
        }
        return Array(padded.prefix(5))
    }

    private static func makeFiveFrameContactSheet(frames: [DepthCameraFrame], highlightBox: CGRect?) -> CGImage? {
        guard !frames.isEmpty else { return nil }
        let size = CGSize(width: 960, height: 960)
        let padding: CGFloat = 16
        let cellWidth = (size.width - padding * 4) / 3
        let cellHeight = (size.height - padding * 3) / 2
        let labels = ["prev 2", "prev 1", "detect", "next 1", "next 2"]
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            for (index, frame) in frames.prefix(5).enumerated() {
                let row = index / 3
                let col = index % 3
                let rect = CGRect(
                    x: padding + CGFloat(col) * (cellWidth + padding),
                    y: padding + CGFloat(row) * (cellHeight + padding),
                    width: cellWidth,
                    height: cellHeight
                )
                let imageRect = aspectFitRect(imageSize: CGSize(width: frame.image.width, height: frame.image.height), in: rect)
                UIImage(cgImage: frame.image).draw(in: imageRect)

                let borderColor = index == 2 ? UIColor.systemOrange : UIColor.white.withAlphaComponent(0.45)
                borderColor.setStroke()
                UIBezierPath(rect: rect).stroke()

                if index == 2, let highlightBox {
                    let highlightRect = CGRect(
                        x: imageRect.minX + highlightBox.minX * imageRect.width,
                        y: imageRect.minY + highlightBox.minY * imageRect.height,
                        width: highlightBox.width * imageRect.width,
                        height: highlightBox.height * imageRect.height
                    )
                    UIColor.systemOrange.setStroke()
                    let path = UIBezierPath(rect: highlightRect)
                    path.lineWidth = 4
                    path.stroke()
                }

                let label = labels[index] as NSString
                label.draw(
                    at: CGPoint(x: rect.minX + 8, y: rect.minY + 8),
                    withAttributes: [
                        .font: UIFont.monospacedSystemFont(ofSize: 20, weight: .semibold),
                        .foregroundColor: UIColor.white
                    ]
                )
            }
        }
        return image.cgImage
    }

    private static func aspectFitRect(imageSize: CGSize, in rect: CGRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return rect }
        let scale = min(rect.width / imageSize.width, rect.height / imageSize.height)
        let width = imageSize.width * scale
        let height = imageSize.height * scale
        return CGRect(
            x: rect.midX - width / 2,
            y: rect.midY - height / 2,
            width: width,
            height: height
        )
    }

    private func recordEvent(
        decision: HazardGateDecision,
        gemmaResult: String?,
        spoken: Bool,
        reviewKind: String
    ) {
        let event = HazardScanEvent(
            time: Date(),
            candidateID: decision.candidateID,
            nearestDepthMeters: decision.nearestDepthMeters,
            hazardLabel: decision.topHazard.label,
            hazardScore: decision.hazardScore,
            safeLabel: decision.topSafe.label,
            safeScore: decision.safeScore,
            margin: decision.margin,
            reason: decision.reason,
            sentToGemma: decision.shouldSendToGemma,
            gemmaResult: gemmaResult,
            spoken: spoken,
            reviewKind: reviewKind
        )
        recentEvents.insert(event, at: 0)
        if recentEvents.count > maximumRecentEvents {
            recentEvents.removeLast(recentEvents.count - maximumRecentEvents)
        }
    }
}
