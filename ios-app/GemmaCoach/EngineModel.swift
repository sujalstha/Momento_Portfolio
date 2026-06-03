// EngineModel.swift
// Wraps CoreMLLLM with @MainActor + @Published state for SwiftUI.
//
// Merged engine: the perception-capable engine (priority generation queue,
// streamCoachVision keyframe path, YOLO hazard gate, voice-command helpers)
// PLUS the Momento download-caching API (downloadModelIfNeeded / isModelDownloaded
// / downloadFraction) used by the Screen-2.5 download view.

import CoreGraphics
import Darwin
import Foundation
import ImageIO
import CoreMLLLM

@MainActor
final class EngineModel: ObservableObject {
    enum GenerationPriority: Int {
        case background = 0
        case safety = 1
        case userInitiated = 2
    }

    enum Status: Equatable {
        case idle
        case downloading(progress: Double)
        case loading
        case ready
        case generating
        case error(String)
    }

    @Published var status: Status = .idle
    @Published var modelPath: URL? = nil
    @Published var output: String = ""
    @Published var lastDecodeTokensPerSecond: Double = 0
    @Published var lastTimeToFirstToken: Double = 0
    @Published var lastTotalTime: Double = 0
    @Published var loadingMessage: String = ""
    @Published var lastHazardGateDecision: HazardGateDecision? = nil

    // Download-screen state (Screen 2.5). Driven by downloadModelIfNeeded().
    @Published var downloadFraction: Double = 0
    @Published var downloadStatusText: String = ""
    /// True once the model is fully downloaded and cached on disk. Seeded from
    /// disk at init so the UI can skip the download screen on later launches.
    @Published var isModelDownloaded: Bool = false

    private var llm: CoreMLLLM? = nil
    private let yoloDepthGate = YOLONanoV11DepthGate()
    private var activeGenerationID: UUID? = nil
    private var activeGenerationPriority: GenerationPriority? = nil
    private var generationWaiters: [GenerationWaiter] = []

    private struct GenerationWaiter {
        let priority: GenerationPriority
        let continuation: CheckedContinuation<UUID, Never>
    }

    init() {
        configureCoreMLLLMEnvironment()
        isModelDownloaded = GemmaDownloader.isFullyDownloaded
    }

    var isReady: Bool {
        if case .ready = status { return true }
        if case .generating = status { return true }
        return false
    }

    var isModelLoaded: Bool { llm != nil }
    var canStartBackgroundGeneration: Bool { llm != nil && activeGenerationID == nil }

    private func configureCoreMLLLMEnvironment() {
        // CoreML-LLM 1.9.0 can race its background prefill warmup against
        // finalPrewarm(), corrupting shared embedding buffers during load.
        setenv("LLM_DEFER_PREFILL", "0", 1)
        // Load model chunks two at a time — faster than sequential, avoids
        // the memory pressure of all-at-once load.
        setenv("LLM_LOAD_MAX_PARALLEL", "2", 1)
    }

    /// Download-only (no CoreML load). Used by the post-onboarding download screen
    /// so the model is fetched once and cached; loading stays lazy (at run start).
    func downloadModelIfNeeded() async {
        if isModelDownloaded || GemmaDownloader.isFullyDownloaded {
            isModelDownloaded = true
            downloadFraction = 1
            return
        }
        status = .downloading(progress: 0)
        downloadFraction = 0
        let downloader = GemmaDownloader()
        downloader.onProgress = { [weak self] (p: Double, msg: String) in
            self?.downloadFraction = p
            self?.downloadStatusText = msg
            self?.status = .downloading(progress: p)
        }
        do {
            _ = try await downloader.download()
            downloadFraction = 1
            isModelDownloaded = true
            status = .idle
        } catch {
            status = .error("\(error)")
        }
    }

    /// Download Gemma 4 E2B and load on ANE + CPU.
    func loadIfNeeded() async {
        if llm != nil { return }
        if case .loading = status { return }
        if case .downloading = status { return }

        status = .downloading(progress: 0)
        loadingMessage = "Preparing…"

        let downloader = GemmaDownloader()
        downloader.onProgress = { [weak self] (progress: Double, message: String) in
            self?.status = .downloading(progress: progress)
            self?.loadingMessage = message
        }

        do {
            let modelDir = try await downloader.download()
            isModelDownloaded = true
            status = .loading
            loadingMessage = "Loading model…"

            let model = try await CoreMLLLM.load(
                from: modelDir,
                computeUnits: .cpuAndNeuralEngine,
                onProgress: { [weak self] msg in
                    Task { @MainActor [weak self] in self?.loadingMessage = msg }
                }
            )
            llm = model
            loadingMessage = ""
            status = .ready
        } catch {
            loadingMessage = ""
            status = .error("\(error)")
        }
    }

    // MARK: - Coaching generation (text + vision)

    /// Streaming coaching with a keyframe image — perception keyframe review.
    func streamCoachVision(
        history: [(role: String, content: String)],
        keyframe: CGImage,
        priority: GenerationPriority = .background,
        onChunk: @MainActor @escaping (String) -> Void
    ) async {
        guard let llm else { status = .error("engine not loaded"); return }
        var formatted = ""
        for turn in history {
            formatted += "<start_of_turn>\(turn.role)\n\(turn.content)<end_of_turn>\n"
        }
        formatted += "<start_of_turn>model\n"
        let generationID = await acquireGeneration(priority: priority)
        guard !Task.isCancelled else { releaseGeneration(generationID); status = .ready; return }
        status = .generating
        output = ""
        let start = Date(); var firstTok: Date? = nil; var totalChars = 0
        do {
            let stream = try await llm.stream(formatted, image: keyframe, maxTokens: 100)
            for await raw in stream {
                try Task.checkCancellation()
                let chunk = filterChunk(raw)
                guard !chunk.isEmpty else { continue }
                if firstTok == nil { firstTok = Date() }
                output += chunk; totalChars += chunk.count
                onChunk(chunk)
            }
            recordTiming(start: start, firstTok: firstTok, totalChars: totalChars)
            status = .ready
            releaseGeneration(generationID)
        } catch is CancellationError {
            status = .ready; releaseGeneration(generationID)
        } catch {
            status = .error("\(error)"); releaseGeneration(generationID)
        }
    }

    /// Streaming coaching from a multi-turn history.
    func streamCoach(
        history: [(role: String, content: String)],
        priority: GenerationPriority = .background,
        onChunk: @MainActor @escaping (String) -> Void
    ) async {
        var formatted = ""
        for turn in history {
            formatted += "<start_of_turn>\(turn.role)\n\(turn.content)<end_of_turn>\n"
        }
        formatted += "<start_of_turn>model\n"
        await streamCoachFormatted(formatted, priority: priority, onChunk: onChunk)
    }

    /// Streaming coaching from a single prompt.
    func streamCoach(
        prompt: String,
        priority: GenerationPriority = .background,
        onChunk: @MainActor @escaping (String) -> Void
    ) async {
        let formatted = "<start_of_turn>user\n\(prompt)<end_of_turn>\n<start_of_turn>model\n"
        await streamCoachFormatted(formatted, priority: priority, onChunk: onChunk)
    }

    private func streamCoachFormatted(
        _ formatted: String,
        priority: GenerationPriority,
        onChunk: @MainActor @escaping (String) -> Void
    ) async {
        guard let llm else { status = .error("engine not loaded"); return }
        let generationID = await acquireGeneration(priority: priority)
        guard !Task.isCancelled else { releaseGeneration(generationID); status = .ready; return }
        status = .generating
        output = ""
        let start = Date(); var firstTok: Date? = nil; var totalChars = 0
        do {
            let stream = try await llm.stream(formatted, maxTokens: 256)
            for await raw in stream {
                try Task.checkCancellation()
                let chunk = filterChunk(raw)
                guard !chunk.isEmpty else { continue }
                if firstTok == nil { firstTok = Date() }
                output += chunk; totalChars += chunk.count
                onChunk(chunk)
            }
            recordTiming(start: start, firstTok: firstTok, totalChars: totalChars)
            status = .ready
            releaseGeneration(generationID)
        } catch is CancellationError {
            status = .ready; releaseGeneration(generationID)
        } catch {
            status = .error("\(error)"); releaseGeneration(generationID)
        }
    }

    /// Short spoken answer to a user voice command (in-run "talk to the app").
    func generateVoiceAnswerInEnglish(_ englishCommand: String) async -> String? {
        guard let llm else { status = .error("engine not loaded"); return nil }
        // Scope-locked: the model may ONLY answer about this runner's metrics,
        // route/weather, run coaching, and goal projections (RunCoachSafety).
        let prompt = """
        \(RunCoachSafety.voiceScopePrompt)

        Runner's request and live data:
        \(englishCommand)
        """
        let formatted = "<start_of_turn>user\n\(prompt)<end_of_turn>\n<start_of_turn>model\n"
        do {
            return try await runReturning(maxTokens: 120, priority: .userInitiated) {
                try await llm.stream(formatted, maxTokens: 120)
            }
        } catch is CancellationError {
            return nil
        } catch {
            status = .error("\(error)"); return nil
        }
    }

    // MARK: - YOLO hazard gate

    func evaluateHazardGate(
        image: CGImage,
        depthSnapshot: DepthFrameSnapshot? = nil
    ) async throws -> HazardGateDecision {
        let decision = try await yoloDepthGate.evaluate(image: image, depthSnapshot: depthSnapshot)
        lastHazardGateDecision = decision
        return decision
    }

    func generateVisionFromApprovedFrame(image: CGImage, prompt: String, maxTokens: Int = 512) async {
        guard let llm else { status = .error("engine not loaded"); return }
        let formatted = "<start_of_turn>user\n\(prompt)<end_of_turn>\n<start_of_turn>model\n"
        await runStreaming(priority: .safety) {
            try await llm.stream(formatted, image: image, maxTokens: maxTokens)
        }
    }

    // MARK: - Generation queue (priority-preemptive, single in-flight)

    private func acquireGeneration(priority: GenerationPriority) async -> UUID {
        if activeGenerationID == nil {
            let id = UUID(); activeGenerationID = id; activeGenerationPriority = priority
            return id
        }
        return await withCheckedContinuation { continuation in
            generationWaiters.append(GenerationWaiter(priority: priority, continuation: continuation))
        }
    }

    private func releaseGeneration(_ id: UUID) {
        guard activeGenerationID == id else { return }
        guard !generationWaiters.isEmpty else {
            activeGenerationID = nil; activeGenerationPriority = nil; return
        }
        let nextIndex = generationWaiters.indices.max {
            generationWaiters[$0].priority.rawValue < generationWaiters[$1].priority.rawValue
        } ?? generationWaiters.startIndex
        let waiter = generationWaiters.remove(at: nextIndex)
        let nextID = UUID()
        activeGenerationID = nextID
        activeGenerationPriority = waiter.priority
        waiter.continuation.resume(returning: nextID)
    }

    // MARK: - Private helpers

    private func recordTiming(start: Date, firstTok: Date?, totalChars: Int) {
        let end = Date()
        lastTimeToFirstToken = firstTok?.timeIntervalSince(start) ?? 0
        lastTotalTime = end.timeIntervalSince(start)
        let decodeT = end.timeIntervalSince(firstTok ?? start)
        lastDecodeTokensPerSecond = Double(max(1, totalChars / 4)) / max(decodeT, 0.001)
    }

    private func filterChunk(_ chunk: String) -> String {
        var s = chunk
        for token in ["<pad>", "<eos>", "</s>", "<end_of_turn>", "<start_of_turn>"] {
            s = s.replacingOccurrences(of: token, with: "")
        }
        return s
    }

    private func runStreaming(
        priority: GenerationPriority,
        _ work: () async throws -> AsyncStream<String>
    ) async {
        let generationID = await acquireGeneration(priority: priority)
        guard !Task.isCancelled else { releaseGeneration(generationID); status = .ready; return }
        status = .generating
        output = ""
        let start = Date(); var firstTok: Date? = nil; var totalChars = 0
        do {
            let stream = try await work()
            for await raw in stream {
                try Task.checkCancellation()
                let chunk = filterChunk(raw)
                guard !chunk.isEmpty else { continue }
                if firstTok == nil { firstTok = Date() }
                output += chunk; totalChars += chunk.count
            }
            recordTiming(start: start, firstTok: firstTok, totalChars: totalChars)
            status = .ready; releaseGeneration(generationID)
        } catch is CancellationError {
            status = .ready; releaseGeneration(generationID)
        } catch {
            status = .error("\(error)"); releaseGeneration(generationID)
        }
    }

    private func runReturning(
        maxTokens: Int,
        priority: GenerationPriority,
        _ work: () async throws -> AsyncStream<String>
    ) async throws -> String {
        let generationID = await acquireGeneration(priority: priority)
        guard !Task.isCancelled else { releaseGeneration(generationID); status = .ready; throw CancellationError() }
        status = .generating
        output = ""
        let start = Date(); var firstTok: Date? = nil; var totalChars = 0; var result = ""
        do {
            let stream = try await work()
            for await raw in stream {
                try Task.checkCancellation()
                let chunk = filterChunk(raw)
                guard !chunk.isEmpty else { continue }
                if firstTok == nil { firstTok = Date() }
                result += chunk; output += chunk; totalChars += chunk.count
            }
        } catch {
            status = error is CancellationError ? .ready : .error("\(error)")
            releaseGeneration(generationID)
            throw error
        }
        recordTiming(start: start, firstTok: firstTok, totalChars: totalChars)
        status = .ready; releaseGeneration(generationID)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
