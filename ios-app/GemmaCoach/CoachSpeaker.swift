// CoachSpeaker.swift
// The coaching-side speech surface, now backed by the shared CartesiaTTS engine
// (Cartesia "rupert – caring dad", with on-device fallback). Keeps the streaming
// buffer interface LiveSession already uses: chunks are buffered as the LLM
// streams, and flush() voices the COMPLETE utterance in one Cartesia call (the
// natural unit for network TTS). isSpeaking mirrors the shared engine.

import Foundation
import Combine
import AVFoundation

@MainActor
final class CoachSpeaker: ObservableObject {
    @Published var isSpeaking: Bool = false

    private let engine = CartesiaTTS.shared
    private var pending: String = ""
    private var cancellable: AnyCancellable?

    init() {
        cancellable = engine.$isSpeaking
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.isSpeaking = $0 }
    }

    /// Buffer a streamed token chunk. Nothing is voiced until flush() — Cartesia
    /// synthesizes whole utterances, so we accumulate the full response first.
    func speak(chunk: String) {
        pending += chunk
    }

    /// Voice a complete utterance immediately (countdowns, one-off lines).
    func speak(_ text: String) {
        engine.speak(text)
    }

    /// Flush the buffered response — voice it as one Cartesia utterance.
    func flush() {
        let text = pending.trimmingCharacters(in: .whitespacesAndNewlines)
        pending = ""
        if !text.isEmpty { engine.speak(text) }
    }

    func cancel() {
        pending = ""
        engine.cancel()
    }

    /// Suspends until speech finishes — paces the coaching loop by speech completion.
    func awaitDrain() async {
        await engine.awaitDrain()
    }

    // MARK: - Audio session (used by the live run loop)

    /// Configure the shared audio session for spoken coaching playback. Cartesia
    /// playback uses this category; the live session activates it on run start.
    func activateCoachAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .spokenAudio,
                                options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
        try session.setActive(true)
    }

    func deactivateCoachAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
