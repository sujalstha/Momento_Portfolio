// ContentView.swift — Watch dashboard.
// Producer-side UI: shows the Watch's own view of the workout while it
// mirrors the same data to the iPhone via HealthKit.

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var workout: WorkoutManager

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {

                mirroringPill

                bigMetric(label: "Heart Rate",
                          value: workout.heartRateBPM > 0 ? "\(Int(workout.heartRateBPM))" : "—",
                          unit: "BPM",
                          tint: .red)

                bigMetric(label: "Pace",
                          value: workout.formattedPace,
                          unit: "",
                          tint: .green)

                HStack(spacing: 8) {
                    smallMetric("Dist", workout.formattedDistance)
                    smallMetric("Cadence", workout.formattedCadence)
                }

                HStack(spacing: 8) {
                    smallMetric("Power", workout.formattedPower)
                    smallMetric("Stride", workout.formattedStride)
                }

                HStack(spacing: 8) {
                    smallMetric("Vert Osc", workout.formattedVerticalOscillation)
                    smallMetric("Gnd Cont", workout.formattedGroundContactTime)
                }

                HStack(spacing: 8) {
                    smallMetric("Kcal", String(format: "%.0f", workout.activeEnergyKcal))
                    smallMetric("Elapsed", workout.formattedElapsed)
                }

                smallMetric("SpO₂", workout.formattedBloodOxygen)

                Button(action: toggle) {
                    HStack(spacing: 6) {
                        if workout.isEnding {
                            ProgressView()
                            Text("Ending…")
                        } else {
                            Image(systemName: workout.isRunning ? "stop.circle.fill" : "play.circle.fill")
                            Text(workout.isRunning ? "Stop" : "Start")
                        }
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                }
                .tint(workout.isRunning ? .red : .green)
                .buttonStyle(.borderedProminent)
                .disabled(workout.isEnding)
                .padding(.top, 4)

                if let err = workout.errorMessage {
                    Text(err)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 6)
        }
        .task { await workout.requestAuthorization() }
    }

    @ViewBuilder
    private var mirroringPill: some View {
        if workout.isRunning {
            HStack(spacing: 4) {
                Image(systemName: workout.mirroringToPhone ? "iphone.and.arrow.left.and.arrow.right" : "iphone.slash")
                    .imageScale(.small)
                Text(workout.mirroringToPhone ? "Mirroring → iPhone" : "Phone not mirrored")
                    .font(.caption2)
            }
            .foregroundStyle(workout.mirroringToPhone ? Color.green : .secondary)
        }
    }

    private func toggle() {
        workout.isRunning ? workout.stop() : workout.start()
    }

    private func bigMetric(label: String, value: String, unit: String, tint: Color) -> some View {
        VStack(spacing: 0) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .foregroundStyle(tint)
                    .monospacedDigit()
                if !unit.isEmpty {
                    Text(unit).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func smallMetric(_ label: String, _ value: String) -> some View {
        VStack(spacing: 0) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.system(.callout, design: .monospaced))
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ContentView().environmentObject(WorkoutManager())
}
