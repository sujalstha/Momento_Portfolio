import CoreGraphics
import CoreImage
import CoreML
import CoreVideo
import Foundation

struct HazardGateLabelScore: Equatable {
    let label: String
    let text: String
    let score: Float

    init(label: String, score: Float, text: String? = nil) {
        self.label = label
        self.text = text ?? label
        self.score = score
    }
}

struct HazardGateDecision: Equatable {
    let shouldSendToGemma: Bool
    let confidence: Float
    let hazardScore: Float
    let safeScore: Float
    let margin: Float
    let topHazard: HazardGateLabelScore
    let topSafe: HazardGateLabelScore
    let candidateID: String
    let nearestDepthMeters: Float?
    let medianDepthMeters: Float?
    let depthConfidence: Float?
    let validDepthPixelRatio: Float
    let nearDepthPixelRatio: Float
    let closeDepthPixelRatio: Float
    let veryCloseDepthPixelRatio: Float
    let normalizedBox: CGRect?
    let reason: String
    let elapsedMs: Double
}

struct YOLONanoDetection: Equatable {
    let classIndex: Int
    let label: String
    let confidence: Float
    let normalizedBox: CGRect

    var areaRatio: Float {
        Float(normalizedBox.width * normalizedBox.height)
    }
}

struct YOLONanoV11GatePolicy: Equatable {
    struct Decision: Equatable {
        let shouldSend: Bool
        let reason: String
        let riskScore: Float
        let routePosition: String
    }

    let minimumDetectionConfidence: Float
    let maximumRelevantDepthMeters: Float
    let sideRouteDepthMeters: Float

    init(
        minimumDetectionConfidence: Float = 0.25,
        maximumRelevantDepthMeters: Float = 1.5,
        sideRouteDepthMeters: Float = 1.5
    ) {
        self.minimumDetectionConfidence = minimumDetectionConfidence
        self.maximumRelevantDepthMeters = maximumRelevantDepthMeters
        self.sideRouteDepthMeters = sideRouteDepthMeters
    }

    func evaluate(detection: YOLONanoDetection, candidate: DepthCandidate?) -> Decision {
        let routePosition = Self.routePosition(for: detection.normalizedBox)
        let closestDepth = candidate?.nearestDepthMeters ?? candidate?.medianDepthMeters
        let visualProximity = Self.visualProximityScore(for: detection.normalizedBox)
        let depthRisk = closestDepth.map { max(0, min(1, (maximumRelevantDepthMeters - $0) / maximumRelevantDepthMeters)) } ?? 0
        let footprintRisk = Self.depthFootprintScore(candidate)
        let objectWeight = Self.routeObstacleWeight(for: detection.label)
        let largeFrameObject = detection.areaRatio >= 0.045 || detection.normalizedBox.height >= 0.34
        let largeDepthObject = footprintRisk >= 0.30
        let objectLooksRelevant = objectWeight >= 0.45 || largeFrameObject || largeDepthObject
        let riskScore = min(1, max(0,
            detection.confidence * objectWeight * 0.50
            + visualProximity * 0.20
            + depthRisk * 0.20
            + footprintRisk * 0.10
        ))

        guard detection.confidence >= minimumDetectionConfidence else {
            return Decision(
                shouldSend: false,
                reason: "yolo_confidence_below_threshold",
                riskScore: riskScore,
                routePosition: routePosition
            )
        }
        guard objectLooksRelevant else {
            return Decision(
                shouldSend: false,
                reason: "yolo_class_not_route_obstacle",
                riskScore: riskScore,
                routePosition: routePosition
            )
        }

        let isDirectRoute = routePosition == "direct path"
        let isSideRoute = routePosition == "side path"
        let insideSafetyEnvelope = closestDepth.map { $0 <= maximumRelevantDepthMeters } ?? false
        let sideClose = closestDepth.map { $0 <= sideRouteDepthMeters } ?? false

        if !isDirectRoute && !isSideRoute {
            return Decision(
                shouldSend: false,
                reason: "yolo_detection_upper_or_far_field",
                riskScore: riskScore,
                routePosition: routePosition
            )
        }
        guard let closestDepth else {
            return Decision(
                shouldSend: false,
                reason: "yolo_local_depth_required",
                riskScore: riskScore,
                routePosition: routePosition
            )
        }
        guard candidate.map({ $0.validDepthPixelRatio >= 0.04 }) ?? false else {
            return Decision(
                shouldSend: false,
                reason: "yolo_local_depth_too_sparse",
                riskScore: riskScore,
                routePosition: routePosition
            )
        }
        if closestDepth > maximumRelevantDepthMeters {
            return Decision(
                shouldSend: false,
                reason: "yolo_object_beyond_1_5m",
                riskScore: riskScore,
                routePosition: routePosition
            )
        }

        if isDirectRoute {
            if insideSafetyEnvelope || largeDepthObject {
                return Decision(
                    shouldSend: true,
                    reason: "yolo_object_direct_path_within_1_5m",
                    riskScore: max(riskScore, 0.55),
                    routePosition: routePosition
                )
            }
            return Decision(
                shouldSend: false,
                reason: "yolo_direct_object_not_inside_1_5m",
                riskScore: riskScore,
                routePosition: routePosition
            )
        }

        if sideClose,
           detection.confidence >= 0.45,
           (largeFrameObject || largeDepthObject) {
            return Decision(
                shouldSend: true,
                reason: "yolo_close_side_object",
                riskScore: max(riskScore, 0.50),
                routePosition: routePosition
            )
        }
        return Decision(
            shouldSend: false,
            reason: "yolo_detection_outside_travel_lane",
            riskScore: riskScore,
            routePosition: routePosition
        )
    }

    func evaluateDepthOnly(candidate: DepthCandidate?) -> Decision {
        let routePosition = candidate.map { Self.routePosition(for: $0.normalizedBox) } ?? "unknown route"
        let closestDepth = candidate?.nearestDepthMeters ?? candidate?.medianDepthMeters
        let medianDepth = candidate?.medianDepthMeters ?? closestDepth
        let depthRisk = closestDepth.map { max(0, min(1, (maximumRelevantDepthMeters - $0) / maximumRelevantDepthMeters)) } ?? 0
        let footprintRisk = Self.depthFootprintScore(candidate)
        let riskScore = min(1, max(0, depthRisk * 0.55 + footprintRisk * 0.45))

        guard let candidate else {
            return Decision(
                shouldSend: false,
                reason: "depth_only_local_depth_required",
                riskScore: riskScore,
                routePosition: routePosition
            )
        }
        guard routePosition == "direct path" else {
            return Decision(
                shouldSend: false,
                reason: "depth_only_not_direct_path",
                riskScore: riskScore,
                routePosition: routePosition
            )
        }
        guard let closestDepth else {
            return Decision(
                shouldSend: false,
                reason: "depth_only_local_depth_required",
                riskScore: riskScore,
                routePosition: routePosition
            )
        }
        guard candidate.validDepthPixelRatio >= 0.18 else {
            return Decision(
                shouldSend: false,
                reason: "depth_only_local_depth_too_sparse",
                riskScore: riskScore,
                routePosition: routePosition
            )
        }
        guard closestDepth <= maximumRelevantDepthMeters else {
            return Decision(
                shouldSend: false,
                reason: "depth_only_surface_beyond_1_5m",
                riskScore: riskScore,
                routePosition: routePosition
            )
        }

        let medianInsideEnvelope = medianDepth.map { $0 <= maximumRelevantDepthMeters } ?? false
        let broadNearSurface = candidate.nearDepthPixelRatio >= 0.35 && medianInsideEnvelope
        let closeSurface = candidate.closeDepthPixelRatio >= 0.12 && (medianDepth ?? closestDepth) <= 1.2
        let veryCloseSurface = candidate.veryCloseDepthPixelRatio >= 0.04 && closestDepth <= 0.6
        guard broadNearSurface || closeSurface || veryCloseSurface else {
            return Decision(
                shouldSend: false,
                reason: "depth_only_not_broad_or_close_enough",
                riskScore: riskScore,
                routePosition: routePosition
            )
        }

        return Decision(
            shouldSend: true,
            reason: "depth_only_close_surface_in_path",
            riskScore: max(riskScore, 0.58),
            routePosition: routePosition
        )
    }

    static func routePosition(for box: CGRect) -> String {
        if box.maxY < 0.38 {
            return "upper or far field"
        }
        if (0.25...0.75).contains(box.midX), box.maxY >= 0.42 {
            return "direct path"
        }
        if box.maxY >= 0.45 {
            return "side path"
        }
        return "upper or far field"
    }

    static func visualProximityScore(for box: CGRect) -> Float {
        let bottom = Float(max(0, min(1, box.maxY)))
        let midY = Float(max(0, min(1, box.midY)))
        let area = min(1, Float(box.width * box.height) * 6)
        return min(1, max(0, bottom * 0.45 + midY * 0.25 + area * 0.30))
    }

    static func routeObstacleWeight(for label: String) -> Float {
        switch label {
        case "person", "bicycle", "car", "motorcycle", "bus", "train", "truck":
            return 1.00
        case "bench", "chair", "couch", "dining table", "potted plant":
            return 0.90
        case "backpack", "umbrella", "handbag", "suitcase", "skateboard":
            return 0.85
        case "traffic light", "fire hydrant", "stop sign", "parking meter":
            return 0.80
        case "sports ball", "bottle", "cup", "bowl", "book", "vase":
            return 0.65
        default:
            return 0.40
        }
    }

    static func depthFootprintScore(_ candidate: DepthCandidate?) -> Float {
        guard let candidate else { return 0 }
        let area = min(1, candidate.normalizedAreaRatio * 3)
        let near = min(1, candidate.nearDepthPixelRatio * 1.6)
        let close = min(1, candidate.closeDepthPixelRatio * 2.5)
        let veryClose = min(1, candidate.veryCloseDepthPixelRatio * 5)
        return min(1, area * 0.25 + near * 0.35 + close * 0.25 + veryClose * 0.15)
    }
}

final class YOLONanoV11DepthGate: @unchecked Sendable {
    private struct ScoredDetection {
        let detection: YOLONanoDetection
        let candidate: DepthCandidate?
        let candidateID: String
        let policyDecision: YOLONanoV11GatePolicy.Decision

        var rankScore: Float {
            policyDecision.riskScore
                + detection.confidence * 0.35
                + (policyDecision.shouldSend ? 1 : 0)
        }
    }

    private static let modelName = "yolo11n"
    private static let imageInputName = "image"
    private static let iouInputName = "iouThreshold"
    private static let confidenceInputName = "confidenceThreshold"
    private static let confidenceOutputName = "confidence"
    private static let coordinatesOutputName = "coordinates"
    private static let inputSize = CGSize(width: 640, height: 640)
    private static let modelConfidenceThreshold: Float = 0.20
    private static let modelIOUThreshold: Float = 0.70

    private let policy: YOLONanoV11GatePolicy
    private let lock = NSLock()
    private var model: MLModel?
    private let ciContext = CIContext(options: [.cacheIntermediates: false])

    init(policy: YOLONanoV11GatePolicy = YOLONanoV11GatePolicy()) {
        self.policy = policy
    }

    func evaluate(
        image: CGImage,
        depthSnapshot: DepthFrameSnapshot? = nil
    ) async throws -> HazardGateDecision {
        let start = Date()
        return try await Task.detached(priority: .userInitiated) { [self] in
            let model = try loadModel()
            let pixelBuffer = try makePixelBuffer(from: image)
            let detections = try Self.detectObjects(
                pixelBuffer: pixelBuffer,
                model: model,
                confidenceThreshold: Self.modelConfidenceThreshold,
                iouThreshold: Self.modelIOUThreshold
            )
            let depthOnlyCandidate = Self.depthOnlyFallbackCandidate(depthSnapshot: depthSnapshot)
            let depthOnlyDecision = depthOnlyCandidate.map { candidate -> HazardGateDecision? in
                let policyDecision = policy.evaluateDepthOnly(candidate: candidate)
                guard policyDecision.shouldSend else { return nil }
                return Self.makeDepthOnlyDecision(
                    candidate: candidate,
                    policyDecision: policyDecision,
                    elapsedMs: Date().timeIntervalSince(start) * 1000
                )
            } ?? nil

            let scoredDetections = detections.map { detection -> ScoredDetection in
                let candidateID = Self.fallbackCandidateID(for: detection.normalizedBox)
                let candidate = Self.localizedDepthCandidate(
                    for: detection,
                    candidateID: candidateID,
                    depthSnapshot: depthSnapshot
                )
                let policyDecision = policy.evaluate(detection: detection, candidate: candidate)
                return ScoredDetection(
                    detection: detection,
                    candidate: candidate,
                    candidateID: candidateID,
                    policyDecision: policyDecision
                )
            }

            guard let selected = Self.selectBestDetection(scoredDetections) else {
                if let depthOnlyDecision {
                    return depthOnlyDecision
                }
                return Self.skipDecision(
                    reason: "no_yolo_detection",
                    elapsedMs: Date().timeIntervalSince(start) * 1000
                )
            }

            let yoloDecision = Self.makeDecision(
                from: selected,
                elapsedMs: Date().timeIntervalSince(start) * 1000
            )
            if yoloDecision.shouldSendToGemma {
                return yoloDecision
            }
            if let depthOnlyDecision {
                return depthOnlyDecision
            }
            return yoloDecision
        }.value
    }

    private func loadModel() throws -> MLModel {
        try lock.withLock {
            if let model { return model }
            let loaded = try Self.loadBundledModel(named: Self.modelName)
            model = loaded
            return loaded
        }
    }

    private static func loadBundledModel(named name: String) throws -> MLModel {
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .cpuAndNeuralEngine
        if let compiledURL = Bundle.main.url(forResource: name, withExtension: "mlmodelc") {
            return try MLModel(contentsOf: compiledURL, configuration: configuration)
        }
        if let packageURL = Bundle.main.url(forResource: name, withExtension: "mlpackage") {
            let compiledURL = try MLModel.compileModel(at: packageURL)
            return try MLModel(contentsOf: compiledURL, configuration: configuration)
        }
        throw YOLONanoV11GateError.modelNotBundled(name)
    }

    private static func detectObjects(
        pixelBuffer: CVPixelBuffer,
        model: MLModel,
        confidenceThreshold: Float,
        iouThreshold: Float
    ) throws -> [YOLONanoDetection] {
        let provider = try MLDictionaryFeatureProvider(dictionary: [
            imageInputName: MLFeatureValue(pixelBuffer: pixelBuffer),
            confidenceInputName: MLFeatureValue(double: Double(confidenceThreshold)),
            iouInputName: MLFeatureValue(double: Double(iouThreshold))
        ])
        let output = try model.prediction(from: provider)
        guard let confidence = output.featureValue(for: confidenceOutputName)?.multiArrayValue else {
            throw YOLONanoV11GateError.outputMissing(confidenceOutputName)
        }
        guard let coordinates = output.featureValue(for: coordinatesOutputName)?.multiArrayValue else {
            throw YOLONanoV11GateError.outputMissing(coordinatesOutputName)
        }
        return parseDetections(confidence: confidence, coordinates: coordinates, minimumConfidence: confidenceThreshold)
    }

    private func makePixelBuffer(from image: CGImage) throws -> CVPixelBuffer {
        let ciImage = CIImage(cgImage: image)
        let sx = Self.inputSize.width / ciImage.extent.width
        let sy = Self.inputSize.height / ciImage.extent.height
        let resized = ciImage.transformed(by: CGAffineTransform(scaleX: sx, y: sy))
            .cropped(to: CGRect(origin: .zero, size: Self.inputSize))

        var pixelBuffer: CVPixelBuffer?
        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        let status = CVPixelBufferCreate(
            nil,
            Int(Self.inputSize.width),
            Int(Self.inputSize.height),
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let pixelBuffer else {
            throw YOLONanoV11GateError.pixelBufferCreateFailed
        }
        ciContext.render(
            resized,
            to: pixelBuffer,
            bounds: CGRect(origin: .zero, size: Self.inputSize),
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        return pixelBuffer
    }

    private static func parseDetections(
        confidence: MLMultiArray,
        coordinates: MLMultiArray,
        minimumConfidence: Float
    ) -> [YOLONanoDetection] {
        guard confidence.shape.count == 2, coordinates.shape.count == 2 else { return [] }
        let rowCount = confidence.shape[0].intValue
        let classCount = min(confidence.shape[1].intValue, cocoLabels.count)
        guard coordinates.shape[0].intValue >= rowCount, coordinates.shape[1].intValue >= 4 else { return [] }

        var detections: [YOLONanoDetection] = []
        for row in 0..<rowCount {
            var bestClass = 0
            var bestScore: Float = 0
            for classIndex in 0..<classCount {
                let score = confidence[[NSNumber(value: row), NSNumber(value: classIndex)]].floatValue
                if score > bestScore {
                    bestScore = score
                    bestClass = classIndex
                }
            }
            guard bestScore >= minimumConfidence else { continue }

            let centerX = coordinates[[NSNumber(value: row), NSNumber(value: 0)]].doubleValue
            let centerY = coordinates[[NSNumber(value: row), NSNumber(value: 1)]].doubleValue
            let width = coordinates[[NSNumber(value: row), NSNumber(value: 2)]].doubleValue
            let height = coordinates[[NSNumber(value: row), NSNumber(value: 3)]].doubleValue
            let box = CGRect(
                x: centerX - width * 0.5,
                y: centerY - height * 0.5,
                width: width,
                height: height
            ).intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
            guard !box.isNull, box.width > 0.001, box.height > 0.001 else { continue }
            detections.append(YOLONanoDetection(
                classIndex: bestClass,
                label: cocoLabels[bestClass],
                confidence: bestScore,
                normalizedBox: box
            ))
        }
        return detections
    }

    private static func selectBestDetection(_ detections: [ScoredDetection]) -> ScoredDetection? {
        let passing = detections.filter(\.policyDecision.shouldSend)
        if let bestPassing = passing.max(by: { $0.rankScore < $1.rankScore }) {
            return bestPassing
        }
        return detections.max(by: { $0.rankScore < $1.rankScore })
    }

    private static func makeDecision(
        from scoredDetection: ScoredDetection,
        elapsedMs: Double
    ) -> HazardGateDecision {
        let detection = scoredDetection.detection
        let candidate = scoredDetection.candidate
        let riskScore = scoredDetection.policyDecision.riskScore
        return HazardGateDecision(
            shouldSendToGemma: scoredDetection.policyDecision.shouldSend,
            confidence: detection.confidence,
            hazardScore: riskScore,
            safeScore: 0,
            margin: riskScore,
            topHazard: HazardGateLabelScore(
                label: detection.label,
                score: detection.confidence,
                text: "YOLO11n COCO class \(detection.classIndex)"
            ),
            topSafe: HazardGateLabelScore(
                label: "not_used",
                score: 0,
                text: "YOLO object gate does not score clear-path text"
            ),
            candidateID: scoredDetection.candidateID,
            nearestDepthMeters: candidate?.nearestDepthMeters,
            medianDepthMeters: candidate?.medianDepthMeters,
            depthConfidence: candidate?.depthConfidence,
            validDepthPixelRatio: candidate?.validDepthPixelRatio ?? 0,
            nearDepthPixelRatio: candidate?.nearDepthPixelRatio ?? 0,
            closeDepthPixelRatio: candidate?.closeDepthPixelRatio ?? 0,
            veryCloseDepthPixelRatio: candidate?.veryCloseDepthPixelRatio ?? 0,
            normalizedBox: detection.normalizedBox,
            reason: scoredDetection.policyDecision.reason,
            elapsedMs: elapsedMs
        )
    }

    private static func makeDepthOnlyDecision(
        candidate: DepthCandidate,
        policyDecision: YOLONanoV11GatePolicy.Decision,
        elapsedMs: Double
    ) -> HazardGateDecision {
        HazardGateDecision(
            shouldSendToGemma: true,
            confidence: max(0.50, min(0.95, policyDecision.riskScore)),
            hazardScore: policyDecision.riskScore,
            safeScore: 0,
            margin: policyDecision.riskScore,
            topHazard: HazardGateLabelScore(
                label: "close obstacle",
                score: policyDecision.riskScore,
                text: "Depth-only broad central surface; YOLO did not provide a reliable class"
            ),
            topSafe: HazardGateLabelScore(
                label: "not_used",
                score: 0,
                text: "YOLO object gate does not score clear-path text"
            ),
            candidateID: candidate.id,
            nearestDepthMeters: candidate.nearestDepthMeters,
            medianDepthMeters: candidate.medianDepthMeters,
            depthConfidence: candidate.depthConfidence,
            validDepthPixelRatio: candidate.validDepthPixelRatio,
            nearDepthPixelRatio: candidate.nearDepthPixelRatio,
            closeDepthPixelRatio: candidate.closeDepthPixelRatio,
            veryCloseDepthPixelRatio: candidate.veryCloseDepthPixelRatio,
            normalizedBox: candidate.normalizedBox,
            reason: policyDecision.reason,
            elapsedMs: elapsedMs
        )
    }

    private static func depthOnlyFallbackCandidate(depthSnapshot: DepthFrameSnapshot?) -> DepthCandidate? {
        depthSnapshot?.summarizeCandidate(
            id: "center_path",
            normalizedBox: CGRect(x: 0.25, y: 0.25, width: 0.50, height: 0.55),
            minimumDepthSamples: 24
        )
    }

    private static func localizedDepthCandidate(
        for detection: YOLONanoDetection,
        candidateID: String,
        depthSnapshot: DepthFrameSnapshot?
    ) -> DepthCandidate? {
        depthSnapshot?.summarizeCandidate(
            id: candidateID,
            normalizedBox: depthProbeBox(for: detection.normalizedBox),
            minimumDepthSamples: 12
        )
    }

    private static func depthProbeBox(for box: CGRect) -> CGRect {
        let expandX = box.width * 0.12
        let expandY = box.height * 0.08
        return CGRect(
            x: box.minX - expandX,
            y: box.minY - expandY,
            width: box.width + expandX * 2,
            height: box.height + expandY * 2
        ).intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
    }

    private static func fallbackCandidateID(for box: CGRect) -> String {
        switch YOLONanoV11GatePolicy.routePosition(for: box) {
        case "direct path":
            return "center_path"
        case "side path":
            return box.midX < 0.5 ? "left_path" : "right_path"
        default:
            return "full_frame"
        }
    }

    private static func skipDecision(reason: String, elapsedMs: Double) -> HazardGateDecision {
        HazardGateDecision(
            shouldSendToGemma: false,
            confidence: 0,
            hazardScore: 0,
            safeScore: 0,
            margin: 0,
            topHazard: HazardGateLabelScore(label: "none", score: 0),
            topSafe: HazardGateLabelScore(label: "not_used", score: 0),
            candidateID: "none",
            nearestDepthMeters: nil,
            medianDepthMeters: nil,
            depthConfidence: nil,
            validDepthPixelRatio: 0,
            nearDepthPixelRatio: 0,
            closeDepthPixelRatio: 0,
            veryCloseDepthPixelRatio: 0,
            normalizedBox: nil,
            reason: reason,
            elapsedMs: elapsedMs
        )
    }

    private static let cocoLabels = [
        "person", "bicycle", "car", "motorcycle", "airplane", "bus", "train", "truck", "boat",
        "traffic light", "fire hydrant", "stop sign", "parking meter", "bench", "bird", "cat",
        "dog", "horse", "sheep", "cow", "elephant", "bear", "zebra", "giraffe", "backpack",
        "umbrella", "handbag", "tie", "suitcase", "frisbee", "skis", "snowboard", "sports ball",
        "kite", "baseball bat", "baseball glove", "skateboard", "surfboard", "tennis racket",
        "bottle", "wine glass", "cup", "fork", "knife", "spoon", "bowl", "banana", "apple",
        "sandwich", "orange", "broccoli", "carrot", "hot dog", "pizza", "donut", "cake",
        "chair", "couch", "potted plant", "bed", "dining table", "toilet", "tv", "laptop",
        "mouse", "remote", "keyboard", "cell phone", "microwave", "oven", "toaster", "sink",
        "refrigerator", "book", "clock", "vase", "scissors", "teddy bear", "hair drier",
        "toothbrush"
    ]
}

enum YOLONanoV11GateError: LocalizedError {
    case modelNotBundled(String)
    case outputMissing(String)
    case pixelBufferCreateFailed

    var errorDescription: String? {
        switch self {
        case .modelNotBundled(let name):
            "\(name).mlmodelc was not found in the app bundle."
        case .outputMissing(let name):
            "YOLO11n output \(name) was not found."
        case .pixelBufferCreateFailed:
            "Could not create YOLO11n input pixel buffer."
        }
    }
}
