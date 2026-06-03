// VoiceInputController.swift
// Always-on speech capture for the voice-first onboarding flow. Wraps
// SFSpeechRecognizer + AVAudioEngine: starts listening, streams a live partial
// transcript, and reports a final transcript after a short silence. Echo's
// prompts are spoken via Cartesia (CartesiaTTS).

import Foundation
import Speech
import AVFoundation

@MainActor
final class VoiceInputController: NSObject, ObservableObject {
    @Published var transcript: String = ""        // live partial
    @Published var isListening: Bool = false
    @Published var authorized: Bool = false
    @Published var lastError: String?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    /// Fires once a final transcription settles (silence after speech).
    var onFinalTranscript: ((String) -> Void)?
    private var silenceTimer: Timer?

    // MARK: - Authorization

    func requestAuthorization() async {
        let speechOK = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }
        let micOK = await AVAudioApplication.requestRecordPermission()
        authorized = speechOK && micOK
        if !authorized { lastError = "Microphone or speech access denied." }
    }

    // MARK: - Speaking (Echo)

    /// Speaks an Echo prompt via the shared Cartesia engine (on-device fallback
    /// when offline). `voiceName` is ignored — the app uses one Cartesia voice
    /// everywhere; the parameter is kept so existing call sites compile.
    func speak(_ text: String, voiceName: String = "", after delay: TimeInterval = 0) {
        guard delay > 0 else { CartesiaTTS.shared.speak(text); return }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            CartesiaTTS.shared.speak(text)
        }
    }

    // MARK: - Listening

    func startListening() {
        guard authorized, !isListening else { return }
        guard let recognizer, recognizer.isAvailable else {
            lastError = "Speech recognition unavailable."
            return
        }
        do {
            try configureRecordSession()
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            self.request = request

            let input = audioEngine.inputNode
            let format = input.outputFormat(forBus: 0)
            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                self?.request?.append(buffer)
            }
            audioEngine.prepare()
            try audioEngine.start()
            isListening = true
            transcript = ""

            task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                guard let self else { return }
                Task { @MainActor in
                    if let result {
                        self.transcript = result.bestTranscription.formattedString
                        self.armSilenceTimer()
                        if result.isFinal { self.finishUtterance() }
                    }
                    if error != nil { self.stopListening() }
                }
            }
        } catch {
            lastError = error.localizedDescription
            stopListening()
        }
    }

    /// Restarts a debounce timer; after 1.4s of no new partials we treat the
    /// current transcript as final (SFSpeech rarely emits isFinal on its own
    /// for continuous capture).
    private func armSilenceTimer() {
        silenceTimer?.invalidate()
        guard !transcript.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 1.4, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.finishUtterance() }
        }
    }

    private func finishUtterance() {
        let final = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        stopListening()
        guard !final.isEmpty else { return }
        onFinalTranscript?(final)
    }

    func stopListening() {
        silenceTimer?.invalidate(); silenceTimer = nil
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        isListening = false
    }

    // MARK: - Audio session

    private func configureRecordSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement,
                                options: [.duckOthers, .defaultToSpeaker])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }
}
