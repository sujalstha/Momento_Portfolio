// CartesiaTTS.swift
// The single voice engine for the whole app. Synthesizes speech via Cartesia
// (sonic-3.5, "rupert – caring dad") over the /tts/bytes endpoint and plays the
// returned WAV. Utterances are serialized through a queue so they never overlap.
//
// Resilience: if Cartesia is unreachable, not configured, or errors, each
// utterance falls back to on-device AVSpeechSynthesizer — so the app still talks
// offline (airplane mode) and never goes silent on a network blip.
//
// Used everywhere via `CartesiaTTS.shared` (onboarding prompts, live coaching
// through CoachSpeaker, metric summaries, the download-screen intro, voice preview).

import Foundation
import AVFoundation

enum CartesiaError: Error {
    case notConfigured
    case http(status: Int, body: Data)
    case badAudio
}

@MainActor
final class CartesiaTTS: NSObject, ObservableObject {
    static let shared = CartesiaTTS()

    @Published private(set) var isSpeaking = false

    private var queue: [String] = []
    private var draining = false
    private var player: AVAudioPlayer?
    private let fallback = AVSpeechSynthesizer()
    private var finish: CheckedContinuation<Void, Never>?
    private let urlSession: URLSession

    private override init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 30
        cfg.waitsForConnectivity = false
        urlSession = URLSession(configuration: cfg)
        super.init()
        fallback.delegate = self
    }

    // MARK: - Public API

    /// Enqueue a complete utterance. Returns immediately; playback is serialized.
    func speak(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        queue.append(t)
        if !draining { Task { await drain() } }
    }

    /// Stop everything and clear the queue.
    func cancel() {
        queue.removeAll()
        player?.stop()
        player = nil
        fallback.stopSpeaking(at: .immediate)
        completeCurrent()
        isSpeaking = false
    }

    /// Suspends until the queue is empty and nothing is playing — used by the
    /// coaching loop to pace the next turn by speech completion.
    func awaitDrain() async {
        while draining || isSpeaking || !queue.isEmpty {
            if Task.isCancelled { return }
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    // MARK: - Queue drain

    private func drain() async {
        guard !draining else { return }
        draining = true
        defer { draining = false; isSpeaking = false }
        configurePlaybackSession()

        while !queue.isEmpty {
            if Task.isCancelled { break }
            let text = queue.removeFirst()
            isSpeaking = true
            do {
                let wav = try await synthesize(text)
                await play(wav)
            } catch {
                // Offline / not configured / API error → on-device voice.
                await speakOnDevice(text)
            }
        }
    }

    // MARK: - Cartesia request

    private func synthesize(_ text: String) async throws -> Data {
        guard CartesiaConfig.isConfigured else { throw CartesiaError.notConfigured }

        var req = URLRequest(url: CartesiaConfig.endpoint)
        req.httpMethod = "POST"
        req.setValue(CartesiaConfig.version, forHTTPHeaderField: "Cartesia-Version")
        req.setValue(CartesiaConfig.apiKey, forHTTPHeaderField: "X-API-Key")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model_id": CartesiaConfig.modelID,
            "transcript": text,
            "voice": ["mode": "id", "id": CartesiaConfig.voiceID],
            "output_format": [
                "container": "wav",
                "encoding": "pcm_s16le",
                "sample_rate": CartesiaConfig.sampleRate,
            ],
            "language": CartesiaConfig.language,
            "generation_config": ["speed": 1.0, "volume": 1.0],
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await urlSession.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw CartesiaError.badAudio }
        guard (200..<300).contains(http.statusCode) else {
            throw CartesiaError.http(status: http.statusCode, body: data)
        }
        guard !data.isEmpty else { throw CartesiaError.badAudio }
        return data
    }

    // MARK: - Playback

    private func play(_ wav: Data) async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            do {
                let p = try AVAudioPlayer(data: wav)
                p.delegate = self
                player = p
                finish = cont
                if !p.play() { completeCurrent() }
            } catch {
                cont.resume()
            }
        }
    }

    private func speakOnDevice(_ text: String) async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            finish = cont
            let u = AVSpeechUtterance(string: text)
            u.voice = AVSpeechSynthesisVoice(identifier: "com.apple.ttsbundle.Daniel-compact")
                ?? AVSpeechSynthesisVoice(language: "en-US")
            u.rate = 0.5
            fallback.speak(u)
        }
    }

    private func completeCurrent() {
        finish?.resume()
        finish = nil
    }

    private func configurePlaybackSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio,
                                 options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
        try? session.setActive(true)
    }
}

// MARK: - Completion callbacks

extension CartesiaTTS: AVAudioPlayerDelegate, AVSpeechSynthesizerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.completeCurrent() }
    }
    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in self.completeCurrent() }
    }
    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) {
        Task { @MainActor in self.completeCurrent() }
    }
    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel u: AVSpeechUtterance) {
        Task { @MainActor in self.completeCurrent() }
    }
}
