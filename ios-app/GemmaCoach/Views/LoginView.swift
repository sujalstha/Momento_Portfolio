// LoginView.swift
// Screen 1 — Sign in. Liquid-Glass dawn layout: "Momento" headline, blue orb,
// and a glass card with Apple / Google / email options. Wired to AuthManager
// (Supabase) per SUPABASE_INTEGRATION.md.

import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var auth: AuthManager
    @State private var showEmailSheet = false

    var body: some View {
        ZStack {
            Backdrop(style: .dawn)

            VStack(spacing: 0) {
                // Top block
                VStack(alignment: .leading, spacing: 10) {
                    Text("welcome").eyebrowStyle()
                    Text("Momento")
                        .font(.system(size: 56, weight: .bold))
                        .tracking(-2)
                        .foregroundStyle(DT.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 36)

                Spacer()

                Orb(size: 196)

                Spacer()

                authCard
            }
            .padding(.horizontal, DT.Spacing.screenH)
            .padding(.bottom, 38)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Momento. Sign in with Apple or Google.")
        .sheet(isPresented: $showEmailSheet) {
            EmailAuthView().environmentObject(auth)
        }
    }

    private var authCard: some View {
        GlassCard(cornerRadius: DT.Radius.lg) {
            VStack(spacing: 8) {
                // Continue with Apple — native button drives the Supabase ID-token flow.
                SignInWithAppleButton(
                    onRequest: auth.handleAppleRequest,
                    onCompletion: { result in
                        Task { await auth.handleAppleCompletion(result) }
                    }
                )
                .signInWithAppleButtonStyle(.black)
                .frame(height: 58)
                .clipShape(Capsule())
                .accessibilityLabel("Continue with Apple")

                // Continue with Google
                Button {
                    Task { await auth.signInWithGoogle() }
                } label: {
                    HStack(spacing: 10) {
                        GoogleGlyph()
                        Text("Continue with Google")
                    }
                }
                .buttonStyle(GlassButtonStyle(variant: .glass))
                .accessibilityLabel("Continue with Google")

                // or divider
                HStack(spacing: 10) {
                    Rectangle().fill(DT.hairline).frame(height: 0.5)
                    Text("or").font(.system(size: 12, weight: .medium)).foregroundStyle(DT.textTertiary)
                    Rectangle().fill(DT.hairline).frame(height: 0.5)
                }
                .padding(.vertical, 2)

                // Use email
                Button {
                    showEmailSheet = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "envelope")
                        Text("Use email")
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 52)
                    .foregroundStyle(DT.textSecondary)
                }
                .accessibilityLabel("Use email")
                .accessibilityHint("Sign in with an email address and password")

                if auth.isLoading {
                    ProgressView().padding(.top, 4)
                }
                if let error = auth.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(DT.vermilion)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
            }
            .padding(14)
        }
    }
}

/// Multicolor Google "G" glyph (matches the design's inline SVG).
private struct GoogleGlyph: View {
    var body: some View {
        ZStack {
            Image(systemName: "g.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(Color(hex: "4285F4"))
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    LoginView().environmentObject(AuthManager())
}
