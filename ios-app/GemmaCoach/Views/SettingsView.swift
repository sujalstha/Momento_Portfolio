// SettingsView.swift
// Screen 6 — Settings tab. Profile card, grouped inset-glass lists (Profile /
// Coaching / Support), and a vermilion Sign out. mist backdrop.

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var profile: ProfileStore

    @State private var showSignOutConfirm = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Settings")
                        .font(.system(size: 34, weight: .bold))
                        .tracking(-1)
                        .foregroundStyle(DT.textPrimary)
                        .padding(.top, DT.Spacing.lg)

                    NavigationLink { PersonalDetailsView() } label: { profileCard }
                        .buttonStyle(PressableScale())
                        .padding(.top, 18)

                    section("Profile") {
                        NavigationLink { PersonalDetailsView() } label: {
                            MomentoListRow(systemIcon: "person", title: "Personal details")
                        }
                    }

                    section("Coaching") {
                        NavigationLink { EchoVoiceView() } label: {
                            MomentoListRow(systemIcon: "headphones", title: "Echo's voice", value: profile.echoVoice)
                        }
                        InsetDivider()
                        Button {
                            profile.units = profile.units == .imperial ? .metric : .imperial
                        } label: {
                            MomentoListRow(systemIcon: "ruler", title: "Units", value: profile.units.label)
                        }
                    }

                    section("Support") {
                        link("questionmark.circle", "Help center", "https://example.com/help")
                        InsetDivider()
                        link("envelope", "Contact us", "mailto:support@momento.app")
                        InsetDivider()
                        link("lock", "Privacy & data", "https://example.com/privacy")
                    }

                    Button(role: .destructive) {
                        showSignOutConfirm = true
                    } label: {
                        Text("Sign out")
                    }
                    .buttonStyle(GlassButtonStyle(variant: .glass, tint: DT.vermilion))
                    .padding(.top, 18)
                    .accessibilityHint("Signs you out and returns to the sign-in screen")

                    Text("Momento v1.0")
                        .font(.footnote)
                        .foregroundStyle(DT.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, DT.Spacing.md)
                }
                .padding(.horizontal, DT.Spacing.screenH)
                .padding(.bottom, 38)
            }
            .scrollIndicators(.hidden)
            .tint(DT.textPrimary)
        }
        .confirmationDialog("Sign out of Momento?", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) {
                Task {
                    await auth.signOut()
                    profile.reset()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var profileCard: some View {
        GlassCard {
            HStack(spacing: 14) {
                Text(profile.avatarInitial)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(Color(hex: "0B0B0F").opacity(0.85)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.displayName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(DT.textPrimary)
                    Text(profile.email.isEmpty ? "Tap to add details" : profile.email)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DT.textTertiary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DT.textQuat)
            }
            .padding(16)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(profile.displayName), \(profile.email). Edit profile.")
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder _ content: @escaping () -> Content) -> some View {
        Text(title).eyebrowStyle()
            .padding(.leading, 4)
            .padding(.top, DT.Spacing.lg)
            .padding(.bottom, 10)
        ListContainer { content() }
    }

    private func link(_ icon: String, _ title: String, _ urlString: String) -> some View {
        Button {
            if let url = URL(string: urlString) { UIApplication.shared.open(url) }
        } label: {
            MomentoListRow(systemIcon: icon, title: title)
        }
    }
}
