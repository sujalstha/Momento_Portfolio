// DownloadingModelView.swift
// Screen 2.5 — downloads the on-device coaching model once, after onboarding,
// before Home. Driven by the real EngineModel/GemmaDownloader (download-only;
// the model is cached to disk and never re-downloaded). Routes to Home via
// RootView once `engine.isModelDownloaded` flips true.
//
// Per the latest spec revision, the "Tip: Echo works offline once installed."
// footer is intentionally omitted.

import SwiftUI

struct DownloadingModelView: View {
    @EnvironmentObject var engine: EngineModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var startedAt = Date()
    @State private var spokenIntro = false

    var body: some View {
        ZStack {
            Backdrop(style: .dawn)

            VStack(spacing: 0) {
                Spacer()

                orbWithRings

                Spacer().frame(height: 36)

                Text("PREPARING ECHO")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.3)
                    .textCase(.uppercase)
                    .foregroundStyle(DT.accent)

                Text("Downloading AI\nCoaching Model")
                    .font(.system(size: 30, weight: .bold))
                    .tracking(-0.84)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(DT.textPrimary)
                    .padding(.top, 10)

                Text("Please wait — this only happens once. Echo will be ready in a moment.")
                    .font(.system(size: 16))
                    .foregroundStyle(DT.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
                    .padding(.top, 12)

                Spacer()

                progressCard
            }
            .padding(.horizontal, DT.Spacing.screenH)
            .padding(.bottom, 24)
        }
        .task { await engine.downloadModelIfNeeded() }
        .onAppear(perform: speakIntroOnce)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(voiceOverLabel)
    }

    // MARK: - Orb + concentric rings

    private var orbWithRings: some View {
        ZStack {
            Circle()
                .stroke(Color.black.opacity(0.10), lineWidth: 1)
                .frame(width: 248, height: 248)
            Circle()
                .stroke(Color.black.opacity(0.18),
                        style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                .frame(width: 200, height: 200)
            Orb(size: 152)
        }
        .accessibilityHidden(true)
    }

    // MARK: - Progress card

    private var progressCard: some View {
        GlassCard(cornerRadius: DT.Radius.md) {
            VStack(spacing: 0) {
                HStack(alignment: .lastTextBaseline) {
                    Text("Coaching model · v1.0")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DT.textPrimary)
                    Spacer()
                    HStack(spacing: 2) {
                        Text("\(percent)")
                            .font(.system(size: 22, weight: .bold))
                            .monospacedDigit()
                            .tracking(-0.44)
                            .foregroundStyle(DT.textPrimary)
                        Text("%")
                            .font(.system(size: 14))
                            .foregroundStyle(DT.textTertiary)
                    }
                }

                ProgressBar(progress: engine.downloadFraction, reduceMotion: reduceMotion)
                    .padding(.top, 12)

                HStack {
                    Text(engine.downloadStatusText.isEmpty ? "Starting…" : engine.downloadStatusText)
                    Spacer()
                    Text(etaText)
                }
                .font(.system(size: 13))
                .monospacedDigit()
                .foregroundStyle(DT.textTertiary)
                .padding(.top, 10)
            }
            .padding(18)
        }
    }

    // MARK: - Derived

    private var percent: Int { Int((engine.downloadFraction * 100).rounded()) }

    private var etaText: String {
        let elapsed = Date.now.timeIntervalSince(startedAt)
        let f = engine.downloadFraction
        guard f > 0.01, elapsed > 1 else { return "calculating…" }
        let remaining = elapsed / f * (1 - f)
        if remaining < 60 { return "~\(Int(remaining.rounded())) sec left" }
        return "~\(Int((remaining / 60).rounded())) min left"
    }

    private var voiceOverLabel: String {
        "Downloading coaching model. \(percent) percent complete. \(etaText)."
    }

    // MARK: - Echo intro (eyes-free)

    private func speakIntroOnce() {
        guard !spokenIntro else { return }
        spokenIntro = true
        CartesiaTTS.shared.speak("Downloading Echo. This only happens once. I'll let you know when I'm ready.")
    }
}

// MARK: - Progress bar (track + gradient fill + leading-edge shine)

private struct ProgressBar: View {
    let progress: Double  // 0...1
    let reduceMotion: Bool

    var body: some View {
        GeometryReader { geo in
            let w = max(8, geo.size.width * progress)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.black.opacity(0.08))
                    .overlay(Capsule().strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5))

                Capsule()
                    .fill(LinearGradient(colors: [Color(hex: "E48700"), Color(hex: "FFA94D")],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: w)
                    .shadow(color: Color(hex: "E48700").opacity(0.45), radius: 16)
                    .overlay(alignment: .trailing) {
                        if !reduceMotion {
                            LinearGradient(colors: [.white.opacity(0), .white.opacity(0.55)],
                                           startPoint: .leading, endPoint: .trailing)
                                .frame(width: 28)
                                .clipShape(Capsule())
                        }
                    }
                    .animation(.easeInOut(duration: 0.4), value: progress)
            }
        }
        .frame(height: 8)
    }
}
