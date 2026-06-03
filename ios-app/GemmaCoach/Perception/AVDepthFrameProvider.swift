import AVFoundation
import CoreImage
import Foundation
import UIKit

final class AVDepthFrameProvider: NSObject, ObservableObject, AVCaptureDataOutputSynchronizerDelegate {
    @Published private(set) var isRunning = false
    @Published private(set) var lastError: String? = nil
    @Published private(set) var lastFrameAt: Date? = nil
    @Published private(set) var lastCandidateCount: Int = 0
    @Published private(set) var lastNearestDepthMeters: Float? = nil
    @Published private(set) var latestPreviewImage: UIImage? = nil

    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let depthOutput = AVCaptureDepthDataOutput()
    private var outputSynchronizer: AVCaptureDataOutputSynchronizer?

    private let configurationQueue = DispatchQueue(label: "GemmaCoach.AVDepthFrameProvider.configuration")
    private let outputQueue = DispatchQueue(label: "GemmaCoach.AVDepthFrameProvider.output")
    private let ciContext = CIContext()
    private let stateLock = NSLock()

    private var latestFrame: DepthCameraFrame?
    private var lastProcessedAt = Date.distantPast
    private let minimumFrameInterval: TimeInterval = 0.75

    static func requestCameraAccessIfNeeded() async -> Bool {
#if targetEnvironment(simulator)
        return true
#else
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    continuation.resume(returning: granted)
                }
            }
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
#endif
    }

    func start() {
        guard !isRunning else { return }
        lastError = nil

#if targetEnvironment(simulator)
        lastError = "Synchronized RGB + depth capture requires a real depth-capable iPhone or iPad."
#else
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard let self else { return }
            if granted {
                self.configurationQueue.async { self.configureAndStartSession() }
            } else {
                DispatchQueue.main.async { self.lastError = "Camera access was denied." }
            }
        }
#endif
    }

    func stop() {
        configurationQueue.async { [weak self] in
            guard let self else { return }
            self.session.stopRunning()
            self.outputSynchronizer?.setDelegate(nil, queue: nil)
            self.outputSynchronizer = nil
            self.stateLock.withLock { self.latestFrame = nil }
            DispatchQueue.main.async {
                self.isRunning = false
            }
        }
    }

    func consumeLatestFrame() -> DepthCameraFrame? {
        stateLock.withLock {
            let frame = latestFrame
            latestFrame = nil
            return frame
        }
    }

    private func configureAndStartSession() {
        do {
            guard !session.isRunning else { return }
            guard let device = Self.makeDepthCapableBackCamera() else {
                publishError("No rear camera with depth output support was found.")
                return
            }

            let input = try AVCaptureDeviceInput(device: device)

            session.beginConfiguration()
            session.sessionPreset = .inputPriority

            guard session.canAddInput(input) else {
                session.commitConfiguration()
                publishError("Could not add depth camera input.")
                return
            }
            session.addInput(input)

            try configureDepthFormat(for: device)
            configureVideoOutput()
            configureDepthOutput()

            guard session.canAddOutput(videoOutput) else {
                session.commitConfiguration()
                publishError("Could not add RGB video output.")
                return
            }
            session.addOutput(videoOutput)

            guard session.canAddOutput(depthOutput) else {
                session.commitConfiguration()
                publishError("Could not add depth output.")
                return
            }
            session.addOutput(depthOutput)

            setPortraitOrientationIfSupported()

            outputSynchronizer = AVCaptureDataOutputSynchronizer(dataOutputs: [videoOutput, depthOutput])
            outputSynchronizer?.setDelegate(self, queue: outputQueue)

            session.commitConfiguration()
            session.startRunning()

            DispatchQueue.main.async {
                self.isRunning = true
                self.lastError = nil
            }
        } catch {
            publishError(error.localizedDescription)
        }
    }

    private func configureDepthFormat(for device: AVCaptureDevice) throws {
        guard let selection = Self.selectDepthFormat(for: device) else {
            publishError("The selected camera does not expose a usable metric depth format.")
            return
        }

        try device.lockForConfiguration()
        device.activeFormat = selection.videoFormat
        device.activeDepthDataFormat = selection.depthFormat
        if device.isFocusModeSupported(.continuousAutoFocus) {
            device.focusMode = .continuousAutoFocus
        }
        if device.isExposureModeSupported(.continuousAutoExposure) {
            device.exposureMode = .continuousAutoExposure
        }
        device.unlockForConfiguration()
    }

    private func configureVideoOutput() {
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true
    }

    private func configureDepthOutput() {
        depthOutput.isFilteringEnabled = true
    }

    private func setPortraitOrientationIfSupported() {
        let portraitRotationAngle: CGFloat = 90
        if let connection = videoOutput.connection(with: .video),
           connection.isVideoRotationAngleSupported(portraitRotationAngle) {
            connection.videoRotationAngle = portraitRotationAngle
        }
        if let connection = depthOutput.connection(with: .depthData),
           connection.isVideoRotationAngleSupported(portraitRotationAngle) {
            connection.videoRotationAngle = portraitRotationAngle
        }
    }

    func dataOutputSynchronizer(
        _ synchronizer: AVCaptureDataOutputSynchronizer,
        didOutput synchronizedDataCollection: AVCaptureSynchronizedDataCollection
    ) {
        let now = Date()
        let shouldProcess = stateLock.withLock { () -> Bool in
            guard now.timeIntervalSince(lastProcessedAt) >= minimumFrameInterval else { return false }
            lastProcessedAt = now
            return true
        }
        guard shouldProcess else { return }

        guard let syncedVideo = synchronizedDataCollection.synchronizedData(for: videoOutput) as? AVCaptureSynchronizedSampleBufferData,
              let syncedDepth = synchronizedDataCollection.synchronizedData(for: depthOutput) as? AVCaptureSynchronizedDepthData,
              !syncedVideo.sampleBufferWasDropped,
              !syncedDepth.depthDataWasDropped,
              let imageBuffer = CMSampleBufferGetImageBuffer(syncedVideo.sampleBuffer)
        else {
            publishError("Waiting for synchronized RGB and depth frames.")
            return
        }

        process(imageBuffer: imageBuffer, depthData: syncedDepth.depthData, capturedAt: now)
    }

    private func process(imageBuffer: CVPixelBuffer, depthData: AVDepthData, capturedAt: Date) {
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            publishError("Could not convert camera RGB frame.")
            return
        }

        let metricDepth = depthData.depthDataType == kCVPixelFormatType_DepthFloat32
            ? depthData
            : depthData.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32)
        let depthSnapshot = DepthFrameSnapshot.make(depthMap: metricDepth.depthDataMap)
        let candidates = depthSnapshot.map { DepthCandidateExtractor.makeDepthCandidates(from: $0) } ?? []
        let nearest = candidates.compactMap(\.nearestDepthMeters).min()
        let frame = DepthCameraFrame(
            image: cgImage,
            depthCandidates: candidates,
            depthSnapshot: depthSnapshot,
            capturedAt: capturedAt
        )

        stateLock.withLock {
            latestFrame = frame
        }

        DispatchQueue.main.async { [weak self] in
            self?.lastError = nil
            self?.lastFrameAt = capturedAt
            self?.lastCandidateCount = candidates.count
            self?.lastNearestDepthMeters = nearest
            self?.latestPreviewImage = UIImage(cgImage: cgImage)
        }
    }

    private func publishError(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.lastError = message
            if message.contains("Could not add") || message.contains("No rear camera") {
                self?.isRunning = false
            }
        }
    }

    private static func makeDepthCapableBackCamera() -> AVCaptureDevice? {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInLiDARDepthCamera,
                .builtInTripleCamera,
                .builtInDualWideCamera,
                .builtInDualCamera,
                .builtInWideAngleCamera
            ],
            mediaType: .video,
            position: .back
        )

        return discovery.devices.first { device in
            device.formats.contains { !$0.supportedDepthDataFormats.isEmpty }
        }
    }

    private static func selectDepthFormat(
        for device: AVCaptureDevice
    ) -> (videoFormat: AVCaptureDevice.Format, depthFormat: AVCaptureDevice.Format)? {
        let candidates = device.formats.compactMap { videoFormat -> (AVCaptureDevice.Format, AVCaptureDevice.Format, Int32, Int32)? in
            guard let depthFormat = selectDepthFormat(from: videoFormat.supportedDepthDataFormats) else { return nil }
            let videoDimensions = CMVideoFormatDescriptionGetDimensions(videoFormat.formatDescription)
            let depthDimensions = CMVideoFormatDescriptionGetDimensions(depthFormat.formatDescription)
            return (videoFormat, depthFormat, videoDimensions.width * videoDimensions.height, depthDimensions.width * depthDimensions.height)
        }

        return candidates.sorted { lhs, rhs in
            if lhs.3 != rhs.3 { return lhs.3 > rhs.3 }
            return lhs.2 < rhs.2
        }.first.map { ($0.0, $0.1) }
    }

    private static func selectDepthFormat(
        from formats: [AVCaptureDevice.Format]
    ) -> AVCaptureDevice.Format? {
        formats.sorted { lhs, rhs in
            let lhsType = CMFormatDescriptionGetMediaSubType(lhs.formatDescription)
            let rhsType = CMFormatDescriptionGetMediaSubType(rhs.formatDescription)
            if lhsType != rhsType {
                return depthTypeRank(lhsType) < depthTypeRank(rhsType)
            }
            let lhsDimensions = CMVideoFormatDescriptionGetDimensions(lhs.formatDescription)
            let rhsDimensions = CMVideoFormatDescriptionGetDimensions(rhs.formatDescription)
            return lhsDimensions.width * lhsDimensions.height > rhsDimensions.width * rhsDimensions.height
        }.first
    }

    private static func depthTypeRank(_ type: FourCharCode) -> Int {
        switch type {
        case kCVPixelFormatType_DepthFloat32: 0
        case kCVPixelFormatType_DepthFloat16: 1
        case kCVPixelFormatType_DisparityFloat32: 2
        case kCVPixelFormatType_DisparityFloat16: 3
        default: 4
        }
    }
}
