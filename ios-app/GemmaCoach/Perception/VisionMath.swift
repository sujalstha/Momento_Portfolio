// VisionMath.swift
// Pure math functions for the vision pipeline — internal so XCTest can reach them
// via @testable import without exposing them in the public API.

import Foundation

enum VisionMath {

    /// Numerically stable softmax over a Float array.
    static func softmax(_ logits: [Float]) -> [Float] {
        guard !logits.isEmpty else { return [] }
        let maxVal = logits.max()!
        var exps = logits.map { exp($0 - maxVal) }
        let sum = exps.reduce(0, +)
        let denom = sum > 1e-8 ? sum : 1
        for i in exps.indices { exps[i] /= denom }
        return exps
    }

    /// Cosine similarity ∈ [-1, 1]. Returns 0 for empty or zero-norm vectors.
    static func cosine(_ a: [Float], _ b: [Float]) -> Float {
        let n = min(a.count, b.count)
        guard n > 0 else { return 0 }
        var dot: Float = 0, normA: Float = 0, normB: Float = 0
        for i in 0..<n {
            dot   += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }
        let denom = sqrt(normA) * sqrt(normB)
        return denom > 1e-8 ? dot / denom : 0
    }

    /// Cosine distance ∈ [0, 2]. 0 = identical, 1 = orthogonal, 2 = opposite.
    static func cosineDistance(_ a: [Float], _ b: [Float]) -> Float {
        1.0 - cosine(a, b)
    }
}
