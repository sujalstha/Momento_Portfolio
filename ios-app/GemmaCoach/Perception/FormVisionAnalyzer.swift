// SceneAheadAnalyzer.swift (file: FormVisionAnalyzer.swift)
// Legacy scene-change gate for the forward-facing camera. The active obstacle
// detector is YOLONanoV11DepthGate; this analyzer only provides optional
// built-in Vision scene context if it is ever started.
//
// This is NOT a coaching pipeline. HealthKit metrics (HR, pace, cadence, GCT, etc.) drive
// coaching via RunMetricsManager. This pipeline drives ALERTS about what is visually ahead.
//
// Change detection:
//   Frame-to-frame cosine distance between consecutive softmax fingerprints. Gate fires when
//   distance > changeThreshold AND >= minFramesBetweenChanges frames since last fire.
//   Gemma receives the keyframe + a safety prompt and decides whether a spoken warning is warranted.

@preconcurrency import AVFoundation
import CoreImage
import Vision

// MARK: - FormVisionAnalyzer

@MainActor
final class FormVisionAnalyzer: ObservableObject {

    enum AnalysisMode { case sceneClassify, simulated }

    struct SceneEvent: Identifiable {
        let id: Int
        let time: Date
        let distance: Float   // cosine distance that triggered this event (0 = first frame / simulated)
        let label: String     // top predicted class label or mode description
    }

    @Published var isRunning = false
    @Published var analysisMode: AnalysisMode = .simulated
    @Published var sceneSummary: String = ""
    @Published var changeCount: Int = 0
    @Published var changeHistory: [SceneEvent] = []

    /// CGImage captured at the moment a scene change is detected. Nil in simulator.
    private(set) var latestKeyframe: CGImage? = nil
    /// True after each new scene-change event until consumeKeyframe() is called.
    private(set) var hasNewKeyframe = false

    private var processor: FrameProcessor?
    private var captureSession: AVCaptureSession?
    private let cameraQueue = DispatchQueue(label: "com.gemmacoach.camera", qos: .userInteractive)

    private var mockTimer: Timer?
    private var mockIndex = 0

    // formSummary alias so LiveSession doesn't need updating.
    var formSummary: String { sceneSummary }

    func start() async {
        guard !isRunning else { return }
        isRunning = true

        #if targetEnvironment(simulator)
        startSimulatedMode()
        #else
        await startCameraMode()
        #endif
    }

    func stop() {
        isRunning = false
        mockTimer?.invalidate(); mockTimer = nil
        processor?.tearDown()
        processor = nil
        captureSession?.stopRunning()
        captureSession = nil
        latestKeyframe = nil
        hasNewKeyframe = false
    }

    /// Acknowledge and take the latest keyframe; resets hasNewKeyframe.
    func consumeKeyframe() -> CGImage? {
        defer { hasNewKeyframe = false }
        return latestKeyframe
    }

    // MARK: - Simulator mode

    // Mock alerts represent environmental hazards/terrain the runner might encounter.
    // These are independent of HealthKit — they simulate what the camera would see ahead.
    private static let mockAlerts = [
        "Uneven pavement ahead. Watch your foot placement.",
        "Sharp downhill approaching. Lean back slightly and shorten your stride.",
        "Pedestrian crossing ahead. Be prepared to slow or yield.",
        "Terrain shifting to gravel. Reduce pace slightly for stability.",
        "Uphill gradient starting. Shorten stride and increase cadence.",
    ]

    private func startSimulatedMode() {
        analysisMode = .simulated
        emitMock()
        mockTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.emitMock() }
        }
    }

    private func emitMock() {
        let label = Self.mockAlerts[mockIndex % Self.mockAlerts.count]
        sceneSummary = label
        mockIndex += 1
        hasNewKeyframe = false
        changeCount += 1
        let event = SceneEvent(id: changeCount, time: Date(), distance: 0, label: label)
        changeHistory.insert(event, at: 0)
        if changeHistory.count > 8 { changeHistory.removeLast() }
    }

    // MARK: - Real-hardware camera mode

    private func startCameraMode() async {
        let proc = FrameProcessor()
        self.processor = proc
        self.analysisMode = proc.mode

        proc.onSceneChange = { [weak self] keyframe, summary, distance, classLabel in
            Task { @MainActor [weak self] in
                guard let self, self.isRunning else { return }
                self.latestKeyframe = keyframe
                self.sceneSummary = summary
                self.hasNewKeyframe = keyframe != nil
                self.changeCount += 1
                let event = SceneEvent(
                    id: self.changeCount,
                    time: Date(),
                    distance: distance,
                    label: classLabel.isEmpty ? String(format: "Δ %.3f", distance) : classLabel
                )
                self.changeHistory.insert(event, at: 0)
                if self.changeHistory.count > 8 { self.changeHistory.removeLast() }
            }
        }

        let session = AVCaptureSession()
        session.sessionPreset = .vga640x480

        // Back camera — phone held or mounted facing forward, toward the route ahead.
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)

        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(proc, queue: cameraQueue)

        guard session.canAddOutput(videoOutput) else { return }
        session.addOutput(videoOutput)

        captureSession = session
        cameraQueue.async { [session] in session.startRunning() }
    }
}

// MARK: - FrameProcessor

private final class FrameProcessor: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {

    var mode: FormVisionAnalyzer.AnalysisMode = .sceneClassify
    var onSceneChange: ((CGImage?, String, Float, String) -> Void)?

    private let classifyRequest = VNClassifyImageRequest()
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    // Accessed only from cameraQueue.
    private var lastFingerprint: [Float]?
    private var framesSinceChange = 0
    private let changeThreshold: Float = 0.12
    private let minFramesBetweenChanges = 30   // ~1 s at 30 fps

    func tearDown() {
        onSceneChange = nil
    }

    // MARK: Frame processing

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let (fingerprint, summary, classLabel) = runSceneClassify(pixelBuffer: pixelBuffer)
        guard !fingerprint.isEmpty else { return }

        let dist: Float
        let isChange: Bool
        if let last = lastFingerprint, framesSinceChange >= minFramesBetweenChanges {
            dist = cosineDistance(fingerprint, last)
            isChange = dist > changeThreshold
        } else {
            dist = 0
            isChange = lastFingerprint == nil  // first frame establishes baseline, no fire
        }

        lastFingerprint = fingerprint

        if isChange {
            framesSinceChange = 0
            print("[SceneClassify] scene change fired — distance=\(String(format: "%.3f", dist)) classes=\(classLabel)")
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let keyframe = ciContext.createCGImage(ciImage, from: ciImage.extent)
            onSceneChange?(keyframe, summary, dist, classLabel)
        } else {
            framesSinceChange += 1
        }
    }

    // MARK: Scene classification fallback (VNClassifyImageRequest)

    private func runSceneClassify(pixelBuffer: CVPixelBuffer) -> ([Float], String, String) {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        try? handler.perform([classifyRequest])

        guard let results = classifyRequest.results, !results.isEmpty else {
            return ([], "", "")
        }

        let fingerprint = results.sorted { $0.identifier < $1.identifier }.map { $0.confidence }

        let topLabels = results
            .filter { $0.confidence > 0.15 }
            .prefix(4)
            .map { $0.identifier }
            .joined(separator: ", ")

        let classLabel = results
            .prefix(3)
            .map { String(format: "%@ %.0f%%", $0.identifier, $0.confidence * 100) }
            .joined(separator: ", ")

        let summary = "Scene classifier detects: \(topLabels). " +
                      "Camera frame attached. Identify any hazards, terrain changes, or obstacles " +
                      "ahead of the runner and issue a brief alert if action is needed. " +
                      "If the scene is clear, say nothing."
        return (fingerprint, summary, classLabel)
    }

    // MARK: Math helpers

    private func cosineDistance(_ a: [Float], _ b: [Float]) -> Float {
        let dot  = zip(a, b).reduce(0) { $0 + $1.0 * $1.1 }
        let normA = sqrt(a.reduce(0) { $0 + $1 * $1 })
        let normB = sqrt(b.reduce(0) { $0 + $1 * $1 })
        guard normA > 0, normB > 0 else { return 0 }
        return 1 - dot / (normA * normB)
    }

}
