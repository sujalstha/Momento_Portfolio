// HealthKitWorkoutSaver.swift
// Best-effort save of a completed run to Apple Health as an HKWorkout. Only
// used for phone-only runs — when the Apple Watch mirrors a session it writes
// its own HKWorkout, so saving again here would double-count.

import Foundation
import HealthKit

enum HealthKitWorkoutSaver {
    /// Takes plain Sendable values — NOT the SwiftData RunRecord — so nothing
    /// reads a model-context-confined object across an `await` (that would be a
    /// SwiftData thread-confinement violation → crash). Caller extracts these on
    /// the main actor before calling.
    static func save(distanceMeters: Double, calories: Int, durationSeconds: Double) async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let store = HKHealthStore()
        let share: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceWalkingRunning),
        ]
        do {
            try await store.requestAuthorization(toShare: share, read: [])

            let end = Date()
            let start = end.addingTimeInterval(-durationSeconds)
            let config = HKWorkoutConfiguration()
            config.activityType = .running
            config.locationType = .outdoor

            let builder = HKWorkoutBuilder(healthStore: store, configuration: config, device: .local())
            try await builder.beginCollection(at: start)

            var samples: [HKSample] = []
            if distanceMeters > 0 {
                samples.append(HKQuantitySample(
                    type: HKQuantityType(.distanceWalkingRunning),
                    quantity: HKQuantity(unit: .meter(), doubleValue: distanceMeters),
                    start: start, end: end))
            }
            if calories > 0 {
                samples.append(HKQuantitySample(
                    type: HKQuantityType(.activeEnergyBurned),
                    quantity: HKQuantity(unit: .kilocalorie(), doubleValue: Double(calories)),
                    start: start, end: end))
            }
            if !samples.isEmpty { try await builder.addSamples(samples) }
            try await builder.endCollection(at: end)
            _ = try await builder.finishWorkout()
        } catch {
            // Non-fatal: the run is already persisted in SwiftData.
            print("HealthKit workout save skipped: \(error.localizedDescription)")
        }
    }
}
