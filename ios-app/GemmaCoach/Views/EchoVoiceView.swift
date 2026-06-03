// EchoVoiceView.swift
// Echo's voice. The app speaks with one Cartesia voice everywhere
// ("Rupert – caring dad" on sonic-3.5), so this screen presents that single
// voice and lets the user preview it. (Multi-voice selection was removed when
// voice output moved to Cartesia.)

import SwiftUI

struct EchoVoiceView: View {
    @EnvironmentObject var profile: ProfileStore

    private let voiceName = "Rupert"
    private let voiceSubtitle = "Caring dad · Cartesia sonic-3.5"

    var body: some View {
        ZStack {
            Backdrop(style: .mist)
            ScrollView {
                VStack(alignment: .leading, spacing: DT.Spacing.md) {
                    Text("Echo's voice")
                        .font(.system(size: 28, weight: .bold))
                        .tracking(-0.8)
                        .foregroundStyle(DT.textPrimary)
                        .padding(.top, 8)

                    Text("Echo speaks with one warm, consistent voice across the whole app. Tap to hear it.")
                        .font(.system(size: 15))
                        .foregroundStyle(DT.textSecondary)

                    ListContainer {
                        Button { preview() } label: { row }
                    }
                }
                .padding(.horizontal, DT.Spacing.screenH)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Voice")
        .navigationBarTitleDisplayMode(.inline)
        .tint(DT.textPrimary)
        .onAppear { profile.echoVoice = voiceName }
        .onDisappear { CartesiaTTS.shared.cancel() }
    }

    private var row: some View {
        HStack(spacing: 14) {
            Image(systemName: "waveform")
                .font(.system(size: 18))
                .foregroundStyle(DT.accent)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(voiceName)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(DT.textPrimary)
                Text(voiceSubtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(DT.textTertiary)
            }
            Spacer()
            Image(systemName: "play.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(DT.accent)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(minHeight: 56)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(voiceName), \(voiceSubtitle). Tap to preview.")
    }

    private func preview() {
        CartesiaTTS.shared.cancel()
        CartesiaTTS.shared.speak("Hi, I'm Echo. I'll be coaching your run, keeping you steady and safe out there.")
    }
}
