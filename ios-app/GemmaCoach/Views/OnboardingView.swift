// OnboardingView.swift
// Screen 2 — voice-first onboarding. 5 steps (Name → Age → Gender → Height →
// Weight). Voice activation is always on: Echo speaks the prompt, then the mic
// listens. A hidden long-press-the-orb gesture opens a typed fallback for users
// who can't or won't speak. mist backdrop.

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var profile: ProfileStore
    @StateObject private var voice = VoiceInputController()

    @State private var step = 0
    @State private var showTypeFallback = false
    @State private var typedValue = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Step {
        let eyebrow = "echo says"
        let title: String
        let hint: String
    }

    private let steps: [Step] = [
        .init(title: "What should I call you?", hint: "Just say your name — I'm listening."),
        .init(title: "How old are you?",        hint: "Say your age in years."),
        .init(title: "How do you identify?",    hint: "Say woman, man, or another term you prefer."),
        .init(title: "How tall are you?",       hint: "Say your height — feet and inches, or centimeters."),
        .init(title: "And your weight?",        hint: "Say your weight in pounds or kilograms."),
    ]

    var body: some View {
        ZStack {
            Backdrop(style: .mist)

            VStack(alignment: .leading, spacing: 0) {
                topBar
                    .padding(.top, 4)

                VStack(alignment: .leading, spacing: 6) {
                    Text(current.eyebrow).eyebrowStyle()
                    Text(current.title)
                        .font(.system(size: 34, weight: .bold))
                        .tracking(-1)
                        .foregroundStyle(DT.textPrimary)
                    Text(current.hint)
                        .font(.system(size: 16))
                        .foregroundStyle(DT.textSecondary)
                        .padding(.top, 2)
                }
                .padding(.top, 28)

                Spacer()

                // Orb + waveform + listening pill
                VStack(spacing: 28) {
                    ZStack {
                        if voice.isListening { PulseRing(diameter: 216) }
                        Orb(size: 196)
                    }
                    .onLongPressGesture { showTypeFallback = true }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel(current.title)
                    .accessibilityHint("Double tap and hold to type your answer instead.")

                    Waveform().opacity(voice.isListening ? 1 : 0.4)

                    listeningPill
                }
                .frame(maxWidth: .infinity)

                Spacer()
            }
            .padding(.horizontal, DT.Spacing.screenH)
            .padding(.bottom, 38)
        }
        .task { await beginStep() }
        .onChange(of: step) { _, _ in Task { await beginStep() } }
        .sheet(isPresented: $showTypeFallback) { typeFallbackSheet }
        .onAppear {
            voice.onFinalTranscript = { transcript in
                Task { @MainActor in advance(with: transcript) }
            }
        }
    }

    private var current: Step { steps[min(step, steps.count - 1)] }

    // MARK: - Top bar (back chevron · progress segments · "n / 5")

    private var topBar: some View {
        HStack {
            Button {
                guard step > 0 else { return }
                voice.stopListening()
                step -= 1
            } label: {
                Image(systemName: "chevron.left").font(.system(size: 17, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(GlassButtonStyle(variant: .glass, large: false))
            .frame(width: 44)
            .opacity(step > 0 ? 1 : 0.35)
            .disabled(step == 0)
            .accessibilityLabel("Back")

            Spacer()

            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { i in
                    Capsule()
                        .fill(i <= step ? DT.textPrimary : DT.hairlineStrong)
                        .frame(height: 4)
                }
            }
            .frame(width: 130)

            Spacer()

            Text("\(step + 1) / 5")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(DT.textTertiary)
                .frame(width: 44, alignment: .trailing)
        }
    }

    private var listeningPill: some View {
        HStack(spacing: 8) {
            Circle().fill(DT.vermilion).frame(width: 8, height: 8)
                .background(Circle().fill(DT.vermilion.opacity(0.18)).frame(width: 16, height: 16))
            Text(voice.isListening ? "Listening" : "Tap and hold the orb to type")
                .font(.system(size: 16))
                .foregroundStyle(DT.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Type fallback

    private var typeFallbackSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text(current.title).font(.title2.bold()).multilineTextAlignment(.center)
                TextField("Type your answer", text: $typedValue)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(step == 1 ? .numberPad : .default)
                    .submitLabel(.done)
                Button("Continue") {
                    let v = typedValue
                    typedValue = ""
                    showTypeFallback = false
                    advance(with: v)
                }
                .buttonStyle(.borderedProminent)
                .disabled(typedValue.trimmingCharacters(in: .whitespaces).isEmpty)
                Spacer()
            }
            .padding()
            .navigationTitle("Type instead")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }

    // MARK: - Flow

    private func beginStep() async {
        if !voice.authorized { await voice.requestAuthorization() }
        let stepAtStart = step

        // Mic OFF while Echo speaks, so the spoken prompt isn't cut off and the
        // mic never transcribes Echo's own voice.
        voice.stopListening()

        // Speak the FULL question, then wait until playback actually finishes
        // before opening the mic. Echo now uses Cartesia (network TTS), so the
        // prompt length is variable — a fixed timer would truncate it.
        CartesiaTTS.shared.speak(current.title)
        try? await Task.sleep(for: .milliseconds(250))   // brief lead-in
        await CartesiaTTS.shared.awaitDrain()            // wait for the prompt to finish

        // Only listen if we're still on the same step and the view is active.
        guard !Task.isCancelled, step == stepAtStart, voice.authorized else { return }
        voice.startListening()
    }

    private func advance(with raw: String) {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        persist(value, for: step)
        voice.stopListening()

        if step < steps.count - 1 {
            step += 1
        } else {
            profile.hasOnboarded = true   // RootView swaps to the tab UI
        }
    }

    /// Parses the spoken/typed value into the right profile field.
    private func persist(_ value: String, for step: Int) {
        switch step {
        case 0:
            profile.name = value.capitalized
        case 1:
            if let age = Self.firstInt(in: value), (5...120).contains(age) { profile.ageYears = age }
        case 2:
            profile.gender = value.capitalized
        case 3:
            profile.heightCm = Self.parseHeightCm(value) ?? profile.heightCm
        case 4:
            profile.weightKg = Self.parseWeightKg(value) ?? profile.weightKg
        default: break
        }
    }

    // MARK: - Parsing helpers

    static func firstInt(in s: String) -> Int? {
        let digits = s.components(separatedBy: CharacterSet.decimalDigits.inverted).filter { !$0.isEmpty }
        return digits.first.flatMap(Int.init)
    }

    /// "5 foot 9", "5 9", "175 cm", "1.75 m" → centimeters.
    static func parseHeightCm(_ s: String) -> Double? {
        let lower = s.lowercased()
        let nums = numbers(in: lower)
        if lower.contains("cm") { return nums.first }
        if lower.contains("meter") || lower.contains(" m") || lower.hasSuffix("m") {
            if let m = nums.first { return m < 3 ? m * 100 : m }
        }
        // feet/inches
        if lower.contains("f") || lower.contains("'") || nums.count >= 2 {
            let feet = nums.first ?? 0
            let inches = nums.count > 1 ? nums[1] : 0
            if feet > 0, feet < 8 { return (feet * 12 + inches) * 2.54 }
        }
        if let single = nums.first { return single > 90 ? single : single * 30.48 } // bare number → cm or feet
        return nil
    }

    /// "150 pounds", "68 kg" → kilograms.
    static func parseWeightKg(_ s: String) -> Double? {
        let lower = s.lowercased()
        guard let n = numbers(in: lower).first else { return nil }
        if lower.contains("kg") || lower.contains("kilo") { return n }
        if lower.contains("lb") || lower.contains("pound") { return n * 0.453592 }
        return n > 40 && n < 400 ? n * 0.453592 : n   // assume pounds in the US default range
    }

    static func numbers(in s: String) -> [Double] {
        s.components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted)
            .filter { !$0.isEmpty }
            .compactMap(Double.init)
    }
}

#Preview {
    OnboardingView()
        .environmentObject(ProfileStore())
}
