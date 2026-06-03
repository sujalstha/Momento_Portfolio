// MetricDetailView.swift
// Screen 5 — pushed from a History card. Hero distance, a "Hear full summary"
// button at the very top (spoken via Cartesia / CartesiaTTS for eyes-free use),
// then a glass card of metric rows. dawn backdrop. No share button.

import SwiftUI

struct MetricDetailView: View {
    let run: RunRecord
    @EnvironmentObject var profile: ProfileStore
    @Environment(\.dismiss) private var dismiss

    @ObservedObject private var tts = CartesiaTTS.shared

    private var imperial: Bool { profile.units.isImperial }

    var body: some View {
        ZStack {
            Backdrop(style: .dawn)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    summaryButton
                        .padding(.top, DT.Spacing.md)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(run.longDateLabel).eyebrowStyle()
                        Text("Morning run")
                            .font(.system(size: 34, weight: .bold))
                            .tracking(-1)
                            .foregroundStyle(DT.textPrimary)
                    }
                    .padding(.top, DT.Spacing.lg)

                    heroMetric.padding(.top, DT.Spacing.md)
                    summaryLine.padding(.top, 4)

                    rowsCard.padding(.top, 18)
                }
                .padding(.horizontal, DT.Spacing.screenH)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("History")
                    }
                }
                .accessibilityLabel("Back to history")
            }
        }
        .tint(DT.textPrimary)
        .onDisappear { CartesiaTTS.shared.cancel() }
    }

    private var summaryButton: some View {
        Button {
            if tts.isSpeaking { CartesiaTTS.shared.cancel() }
            else { speakSummary() }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: tts.isSpeaking ? "stop.fill" : "speaker.wave.2.fill")
                Text(tts.isSpeaking ? "Stop" : "Hear full summary")
            }
        }
        .buttonStyle(GlassButtonStyle(variant: .glassStrong))
        .accessibilityHint("Reads the run summary aloud")
    }

    private var heroMetric: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(run.distanceValue(imperial: imperial))
                .font(.system(size: 80, weight: .bold))
                .monospacedDigit()
                .tracking(-3)
                .foregroundStyle(DT.textPrimary)
            Text(run.distanceUnit(imperial: imperial))
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(DT.textTertiary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(run.distanceValue(imperial: imperial)) \(imperial ? "miles" : "kilometers")")
    }

    private var summaryLine: some View {
        (Text("in ") + Text(run.formattedDuration).bold().foregroundColor(DT.textPrimary)
            + Text(" · \(run.formattedPace(imperial: imperial)) avg · coached"))
            .font(.system(size: 16))
            .monospacedDigit()
            .foregroundStyle(DT.textSecondary)
    }

    private var rowsCard: some View {
        ListContainer {
            ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                if i > 0 { InsetDivider() }
                MetricRow(label: row.label, value: row.value, unit: row.unit)
            }
        }
    }

    private struct Row { let label, value, unit: String }

    private var rows: [Row] {
        [
            Row(label: "Heart rate",     value: "\(run.avgHeartRateBPM)", unit: "bpm avg"),
            Row(label: "Cadence",        value: "\(run.avgCadenceSPM)", unit: "spm"),
            Row(label: "Power",          value: "\(run.avgPowerWatts)", unit: "w"),
            Row(label: "Stride length",  value: String(format: "%.2f", run.avgStrideLengthMeters), unit: "m"),
            Row(label: "Ground contact", value: "\(run.avgGroundContactTimeMs)", unit: "ms"),
            Row(label: "Vert oscillation", value: String(format: "%.1f", run.avgVerticalOscillationCm), unit: "cm"),
            Row(label: "Calories",       value: "\(run.caloriesKcal)", unit: "kcal"),
            Row(label: "Blood oxygen",   value: "\(run.bloodOxygenPercent)", unit: "%"),
            Row(label: "Elevation gain", value: "+\(run.elevationGainMeters)", unit: "m"),
        ]
    }

    // MARK: - Spoken summary

    private func speakSummary() {
        let unitWord = imperial ? "miles" : "kilometers"
        let paceWord = run.formattedPace(imperial: imperial)
            .replacingOccurrences(of: "/mi", with: "per mile")
            .replacingOccurrences(of: "/km", with: "per kilometer")
        let text = """
        Your run was \(run.distanceValue(imperial: imperial)) \(unitWord) in \(spokenDuration), \
        average pace \(paceWord). Average heart rate \(run.avgHeartRateBPM) beats per minute. \
        Cadence \(run.avgCadenceSPM) steps per minute. Power \(run.avgPowerWatts) watts. \
        You burned \(run.caloriesKcal) calories, with blood oxygen at \(run.bloodOxygenPercent) percent \
        and \(run.elevationGainMeters) meters of elevation gain.
        """
        CartesiaTTS.shared.speak(text)
    }

    private var spokenDuration: String {
        let total = Int(run.durationSeconds)
        let m = total / 60, s = total % 60
        if m == 0 { return "\(s) seconds" }
        return s == 0 ? "\(m) minutes" : "\(m) minutes \(s) seconds"
    }
}
