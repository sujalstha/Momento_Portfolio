// PersonalDetailsView.swift
// Edit the profile collected during onboarding: name, email, age, gender,
// height, weight. Pushed from Settings. Values persist via ProfileStore.

import SwiftUI

struct PersonalDetailsView: View {
    @EnvironmentObject var profile: ProfileStore

    @State private var name = ""
    @State private var email = ""
    @State private var age = ""
    @State private var gender = ""
    @State private var heightText = ""
    @State private var weightText = ""

    private var imperial: Bool { profile.units.isImperial }

    var body: some View {
        ZStack {
            Backdrop(style: .mist)
            ScrollView {
                VStack(alignment: .leading, spacing: DT.Spacing.md) {
                    Text("Personal details")
                        .font(.system(size: 28, weight: .bold))
                        .tracking(-0.8)
                        .foregroundStyle(DT.textPrimary)
                        .padding(.top, 8)

                    ListContainer {
                        field("Name", text: $name, content: .name)
                        InsetDivider()
                        field("Email", text: $email, content: .emailAddress, keyboard: .emailAddress)
                        InsetDivider()
                        field("Age", text: $age, keyboard: .numberPad)
                        InsetDivider()
                        field("Gender", text: $gender)
                        InsetDivider()
                        field(imperial ? "Height (in)" : "Height (cm)", text: $heightText, keyboard: .decimalPad)
                        InsetDivider()
                        field(imperial ? "Weight (lb)" : "Weight (kg)", text: $weightText, keyboard: .decimalPad)
                    }
                }
                .padding(.horizontal, DT.Spacing.screenH)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .tint(DT.textPrimary)
        .onAppear(perform: load)
        .onDisappear(perform: save)
    }

    private func field(_ label: String, text: Binding<String>,
                       content: UITextContentType? = nil,
                       keyboard: UIKeyboardType = .default) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(DT.textPrimary)
                .frame(width: 120, alignment: .leading)
            TextField("", text: text)
                .multilineTextAlignment(.trailing)
                .keyboardType(keyboard)
                .textContentType(content)
                .autocorrectionDisabled(content == .emailAddress)
                .textInputAutocapitalization(content == .emailAddress ? .never : .words)
                .foregroundStyle(DT.textSecondary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private func load() {
        name = profile.name
        email = profile.email
        age = profile.ageYears > 0 ? "\(profile.ageYears)" : ""
        gender = profile.gender
        if profile.heightCm > 0 {
            heightText = imperial ? String(format: "%.0f", profile.heightCm / 2.54)
                                  : String(format: "%.0f", profile.heightCm)
        }
        if profile.weightKg > 0 {
            weightText = imperial ? String(format: "%.0f", profile.weightKg / 0.453592)
                                  : String(format: "%.0f", profile.weightKg)
        }
    }

    private func save() {
        profile.name = name.trimmingCharacters(in: .whitespaces)
        profile.email = email.trimmingCharacters(in: .whitespaces)
        if let a = Int(age) { profile.ageYears = a }
        profile.gender = gender.trimmingCharacters(in: .whitespaces)
        if let h = Double(heightText), h > 0 {
            profile.heightCm = imperial ? h * 2.54 : h
        }
        if let w = Double(weightText), w > 0 {
            profile.weightKg = imperial ? w * 0.453592 : w
        }
    }
}
