// HistoryView.swift
// Screen 4 — History tab. At most two coached session cards (older runs sync
// silently to Apple Health). Each card pushes a Metric detail. mist backdrop.

import SwiftUI
import SwiftData

struct HistoryView: View {
    @EnvironmentObject var profile: ProfileStore
    @Query(sort: \RunRecord.startedAt, order: .reverse) private var runs: [RunRecord]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("your runs").eyebrowStyle()
                        Text("History")
                            .font(.system(size: 34, weight: .bold))
                            .tracking(-1)
                            .foregroundStyle(DT.textPrimary)
                    }
                    .padding(.top, DT.Spacing.lg)

                    if runs.isEmpty {
                        emptyState
                    } else {
                        VStack(spacing: DT.Spacing.md) {
                            ForEach(Array(runs.prefix(2))) { run in
                                NavigationLink {
                                    MetricDetailView(run: run)
                                } label: {
                                    HistoryCard(run: run, imperial: profile.units.isImperial)
                                }
                                .buttonStyle(PressableScale())
                            }
                        }
                        .padding(.top, 18)
                    }
                }
                .padding(.horizontal, DT.Spacing.screenH)
                .padding(.bottom, 38)
            }
            .scrollIndicators(.hidden)
            .background(Color.clear)
        }
        .tint(DT.textPrimary)
    }

    private var emptyState: some View {
        GlassCard(cornerRadius: DT.Radius.lg) {
            VStack(spacing: 10) {
                Image(systemName: "figure.run")
                    .font(.system(size: 36))
                    .foregroundStyle(DT.textTertiary)
                Text("No runs yet")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(DT.textPrimary)
                Text("Finish a coached run and it'll show up here.")
                    .font(.system(size: 15))
                    .foregroundStyle(DT.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(28)
        }
        .padding(.top, 18)
        .accessibilityElement(children: .combine)
    }
}

struct HistoryCard: View {
    let run: RunRecord
    let imperial: Bool

    var body: some View {
        GlassCard(cornerRadius: DT.Radius.lg) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Pill(text: "Coached", systemIcon: "headphones",
                         tint: DT.accent, fill: DT.accent.opacity(0.14))
                    Spacer()
                    Text(run.relativeDateLabel)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DT.textTertiary)
                }
                Spacer(minLength: 12)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(run.distanceValue(imperial: imperial))
                        .font(.system(size: 56, weight: .bold))
                        .monospacedDigit()
                        .tracking(-2)
                        .foregroundStyle(DT.textPrimary)
                    Text(run.distanceUnit(imperial: imperial))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(DT.textTertiary)
                }
                HStack(alignment: .firstTextBaseline) {
                    Text("\(run.formattedDuration) · \(run.formattedPace(imperial: imperial))")
                        .font(.system(size: 16))
                        .monospacedDigit()
                        .foregroundStyle(DT.textSecondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DT.textQuat)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 172, alignment: .topLeading)
            .padding(22)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Coached run, \(run.distanceValue(imperial: imperial)) \(run.distanceUnit(imperial: imperial)), \(run.relativeDateLabel)")
        .accessibilityHint("Opens the run breakdown")
    }
}
