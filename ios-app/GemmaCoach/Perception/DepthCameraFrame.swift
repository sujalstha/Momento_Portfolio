import CoreGraphics
import CoreVideo
import Foundation

struct DepthCandidate: Equatable {
    let id: String
    let normalizedBox: CGRect
    let nearestDepthMeters: Float?
    let medianDepthMeters: Float?
    let depthConfidence: Float?
    let validDepthPixelRatio: Float
    let nearDepthPixelRatio: Float
    let closeDepthPixelRatio: Float
    let veryCloseDepthPixelRatio: Float

    init(
        id: String,
        normalizedBox: CGRect,
        nearestDepthMeters: Float?,
        medianDepthMeters: Float?,
        depthConfidence: Float?,
        validDepthPixelRatio: Float = 0,
        nearDepthPixelRatio: Float = 0,
        closeDepthPixelRatio: Float = 0,
        veryCloseDepthPixelRatio: Float = 0
    ) {
        self.id = id
        self.normalizedBox = normalizedBox
        self.nearestDepthMeters = nearestDepthMeters
        self.medianDepthMeters = medianDepthMeters
        self.depthConfidence = depthConfidence
        self.validDepthPixelRatio = validDepthPixelRatio
        self.nearDepthPixelRatio = nearDepthPixelRatio
        self.closeDepthPixelRatio = closeDepthPixelRatio
        self.veryCloseDepthPixelRatio = veryCloseDepthPixelRatio
    }

    var normalizedAreaRatio: Float {
        Float(normalizedBox.width * normalizedBox.height)
    }

    static let fullFrame = DepthCandidate(
        id: "full_frame",
        normalizedBox: CGRect(x: 0, y: 0, width: 1, height: 1),
        nearestDepthMeters: nil,
        medianDepthMeters: nil,
        depthConfidence: nil
    )
}

struct DepthCameraFrame {
    let image: CGImage
    let depthCandidates: [DepthCandidate]
    let depthSnapshot: DepthFrameSnapshot?
    let capturedAt: Date
}

struct DepthFrameSnapshot {
    let width: Int
    let height: Int
    private let depthValues: [Float]
    private let confidenceValues: [UInt8]?

    static func make(depthMap: CVPixelBuffer, confidenceMap: CVPixelBuffer? = nil) -> DepthFrameSnapshot? {
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        if let confidenceMap {
            CVPixelBufferLockBaseAddress(confidenceMap, .readOnly)
        }
        defer {
            CVPixelBufferUnlockBaseAddress(depthMap, .readOnly)
            if let confidenceMap {
                CVPixelBufferUnlockBaseAddress(confidenceMap, .readOnly)
            }
        }

        guard let depthBase = CVPixelBufferGetBaseAddress(depthMap)?.assumingMemoryBound(to: Float32.self) else {
            return nil
        }

        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        let depthStride = CVPixelBufferGetBytesPerRow(depthMap) / MemoryLayout<Float32>.stride
        var depthValues = [Float](repeating: 0, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                depthValues[y * width + x] = depthBase[y * depthStride + x]
            }
        }

        let confidenceValues: [UInt8]?
        if let confidenceMap,
           CVPixelBufferGetWidth(confidenceMap) == width,
           CVPixelBufferGetHeight(confidenceMap) == height,
           let confidenceBase = CVPixelBufferGetBaseAddress(confidenceMap)?.assumingMemoryBound(to: UInt8.self) {
            let confidenceStride = CVPixelBufferGetBytesPerRow(confidenceMap)
            var values = [UInt8](repeating: 0, count: width * height)
            for y in 0..<height {
                for x in 0..<width {
                    values[y * width + x] = confidenceBase[y * confidenceStride + x]
                }
            }
            confidenceValues = values
        } else {
            confidenceValues = nil
        }

        return DepthFrameSnapshot(
            width: width,
            height: height,
            depthValues: depthValues,
            confidenceValues: confidenceValues
        )
    }

    func summarizeCandidate(
        id: String,
        normalizedBox box: CGRect,
        minimumDepthSamples: Int = 24
    ) -> DepthCandidate? {
        let unitRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        let clamped = box.intersection(unitRect)
        guard !clamped.isNull, clamped.width > 0.001, clamped.height > 0.001 else { return nil }

        let startX = max(0, min(width - 1, Int(floor(clamped.minX * CGFloat(width)))))
        let endX = max(startX + 1, min(width, Int(ceil(clamped.maxX * CGFloat(width)))))
        let startY = max(0, min(height - 1, Int(floor(clamped.minY * CGFloat(height)))))
        let endY = max(startY + 1, min(height, Int(ceil(clamped.maxY * CGFloat(height)))))
        let totalPixels = max(1, (endX - startX) * (endY - startY))

        var depths: [Float] = []
        var nearDepthCount = 0
        var closeDepthCount = 0
        var veryCloseDepthCount = 0
        var confidenceSum: Float = 0
        var confidenceCount: Float = 0

        for y in startY..<endY {
            for x in startX..<endX {
                let value = depthValues[y * width + x]
                guard value.isFinite, value > 0.05, value < 8.0 else { continue }
                depths.append(value)
                if value <= 1.5 { nearDepthCount += 1 }
                if value <= 1.0 { closeDepthCount += 1 }
                if value <= 0.5 { veryCloseDepthCount += 1 }

                if let confidenceValues {
                    confidenceSum += Float(confidenceValues[y * width + x]) / 2.0
                    confidenceCount += 1
                }
            }
        }

        guard depths.count >= minimumDepthSamples else { return nil }
        depths.sort()
        let nearestIndex = min(depths.count - 1, max(0, depths.count / 20))
        let medianIndex = depths.count / 2
        let confidence = confidenceCount > 0 ? confidenceSum / confidenceCount : nil

        return DepthCandidate(
            id: id,
            normalizedBox: clamped,
            nearestDepthMeters: depths[nearestIndex],
            medianDepthMeters: depths[medianIndex],
            depthConfidence: confidence,
            validDepthPixelRatio: Float(depths.count) / Float(totalPixels),
            nearDepthPixelRatio: Float(nearDepthCount) / Float(totalPixels),
            closeDepthPixelRatio: Float(closeDepthCount) / Float(totalPixels),
            veryCloseDepthPixelRatio: Float(veryCloseDepthCount) / Float(totalPixels)
        )
    }
}

enum DepthCandidateExtractor {
    static func makeDepthCandidates(
        depthMap: CVPixelBuffer,
        confidenceMap: CVPixelBuffer? = nil
    ) -> [DepthCandidate] {
        guard let snapshot = DepthFrameSnapshot.make(depthMap: depthMap, confidenceMap: confidenceMap) else { return [] }
        return makeDepthCandidates(from: snapshot)
    }

    static func makeDepthCandidates(from snapshot: DepthFrameSnapshot) -> [DepthCandidate] {
        var boxes: [(String, CGRect)] = []
        for row in 0..<4 {
            for col in 0..<4 {
                boxes.append(("tile_\(row)_\(col)", CGRect(
                    x: CGFloat(col) * 0.25,
                    y: CGFloat(row) * 0.25,
                    width: 0.25,
                    height: 0.25
                )))
            }
        }
        boxes.append(("ground_near", CGRect(x: 0.15, y: 0.55, width: 0.70, height: 0.40)))
        boxes.append(("center_path", CGRect(x: 0.25, y: 0.25, width: 0.50, height: 0.55)))
        boxes.append(("left_path", CGRect(x: 0.00, y: 0.35, width: 0.45, height: 0.55)))
        boxes.append(("right_path", CGRect(x: 0.55, y: 0.35, width: 0.45, height: 0.55)))

        let scored = boxes.compactMap { id, box -> DepthCandidate? in
            snapshot.summarizeCandidate(
                id: id,
                normalizedBox: box
            )
        }

        return scored
            .filter { ($0.nearestDepthMeters ?? .greatestFiniteMagnitude) <= 3.2 }
            .sorted {
                ($0.nearestDepthMeters ?? .greatestFiniteMagnitude) < ($1.nearestDepthMeters ?? .greatestFiniteMagnitude)
            }
            .prefix(6)
            .map { $0 }
    }
}
