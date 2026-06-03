// RunRecord.swift
// SwiftData model for a completed run. Persisted locally and surfaced in the
// History tab + Metric detail. Field names mirror GemmaCoach-Metrics.md so the
// pipeline → storage → UI mapping is 1:1.

import Foundation
import SwiftData

@Model
final class RunRecord {
    var id: UUID
    var startedAt: Date
    var durationSeconds: Double
    var distanceMeters: Double
    var isCoached: Bool

    // Averaged / summary metrics captured at run end.
    var avgHeartRateBPM: Int
    var avgCadenceSPM: Int
    var avgPowerWatts: Int
    var avgStrideLengthMeters: Double
    var avgGroundContactTimeMs: Int
    var avgVerticalOscillationCm: Double
    var caloriesKcal: Int
    var bloodOxygenPercent: Int
    var elevationGainMeters: Int

    init(
        id: UUID = UUID(),
        startedAt: Date = .now,
        durationSeconds: Double = 0,
        distanceMeters: Double = 0,
        isCoached: Bool = true,
        avgHeartRateBPM: Int = 0,
        avgCadenceSPM: Int = 0,
        avgPowerWatts: Int = 0,
        avgStrideLengthMeters: Double = 0,
        avgGroundContactTimeMs: Int = 0,
        avgVerticalOscillationCm: Double = 0,
        caloriesKcal: Int = 0,
        bloodOxygenPercent: Int = 0,
        elevationGainMeters: Int = 0
    ) {
        self.id = id
        self.startedAt = startedAt
        self.durationSeconds = durationSeconds
        self.distanceMeters = distanceMeters
        self.isCoached = isCoached
        self.avgHeartRateBPM = avgHeartRateBPM
        self.avgCadenceSPM = avgCadenceSPM
        self.avgPowerWatts = avgPowerWatts
        self.avgStrideLengthMeters = avgStrideLengthMeters
        self.avgGroundContactTimeMs = avgGroundContactTimeMs
        self.avgVerticalOscillationCm = avgVerticalOscillationCm
        self.caloriesKcal = caloriesKcal
        self.bloodOxygenPercent = bloodOxygenPercent
        self.elevationGainMeters = elevationGainMeters
    }
}

// MARK: - Display formatting (Imperial/Metric aware)

extension RunRecord {
    var distanceKm: Double { distanceMeters / 1000 }
    var distanceMiles: Double { distanceMeters / 1609.34 }

    /// "4.2" — primary distance number for the unit system.
    func distanceValue(imperial: Bool) -> String {
        String(format: "%.1f", imperial ? distanceMiles : distanceKm)
    }
    func distanceUnit(imperial: Bool) -> String { imperial ? "mi" : "km" }

    /// "34:12"
    var formattedDuration: String {
        let total = Int(durationSeconds)
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s)
                     : String(format: "%d:%02d", m, s)
    }

    /// "8:08 /mi" or "5:02 /km" — average pace.
    func formattedPace(imperial: Bool) -> String {
        guard distanceMeters > 0, durationSeconds > 0 else { return "—" }
        let perUnit = durationSeconds / (imperial ? distanceMiles : distanceKm)
        guard perUnit.isFinite, perUnit > 0 else { return "—" }
        let m = Int(perUnit) / 60, s = Int(perUnit) % 60
        return String(format: "%d:%02d /%@", m, s, imperial ? "mi" : "km")
    }

    /// "Yesterday · 7:14 AM" style relative label for history cards.
    var relativeDateLabel: String {
        let cal = Calendar.current
        let time = startedAt.formatted(date: .omitted, time: .shortened)
        if cal.isDateInToday(startedAt) { return "Today · \(time)" }
        if cal.isDateInYesterday(startedAt) { return "Yesterday · \(time)" }
        let day = startedAt.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        return "\(day) · \(time)"
    }

    /// "Friday May 22 · 7:14 AM" — long header for metric detail.
    var longDateLabel: String {
        let day = startedAt.formatted(.dateTime.weekday(.wide).month(.wide).day())
        let time = startedAt.formatted(date: .omitted, time: .shortened)
        return "\(day) · \(time)"
    }
}
