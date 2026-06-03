// EmailAuthView.swift
// Email path for sign in — presented from the "Use email" button on LoginView.
// Sign in, create account, or request a magic link via Supabase.

import SwiftUI

struct EmailAuthView: View {
    @EnvironmentObject var auth: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var magicLinkSent = false

    @FocusState private var focused: Field?
    private enum Field { case email, password }

    var body: some View {
        NavigationStack {
            ZStack {
                Backdrop(style: .dawn)
                ScrollView {
                    VStack(spacing: DT.Spacing.md) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("sign in").eyebrowStyle()
                            Text("Use email")
                                .font(.system(size: 34, weight: .bold))
                                .tracking(-1)
                                .foregroundStyle(DT.textPrimary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)

                        GlassCard {
                            VStack(spacing: 0) {
                                fieldRow {
                                    TextField("Email", text: $email)
                                        .textContentType(.emailAddress)
                                        .keyboardType(.emailAddress)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                        .focused($focused, equals: .email)
                                        .submitLabel(.next)
                                        .onSubmit { focused = .password }
                                }
                                InsetDivider()
                                fieldRow {
                                    SecureField("Password", text: $password)
                                        .textContentType(.password)
                                        .focused($focused, equals: .password)
                                        .submitLabel(.go)
                                        .onSubmit(signIn)
                                }
                            }
                        }

                        Button("Sign in", action: signIn)
                            .buttonStyle(GlassButtonStyle(variant: .dark))
                            .disabled(!canSubmit)
                            .opacity(canSubmit ? 1 : 0.5)

                        Button("Create account") {
                            Task { await auth.signUp(email: email, password: password) }
                        }
                        .buttonStyle(GlassButtonStyle(variant: .glass))
                        .disabled(!canSubmit)
                        .opacity(canSubmit ? 1 : 0.5)

                        Button {
                            Task {
                                await auth.sendMagicLink(to: email)
                                if auth.errorMessage == nil { magicLinkSent = true }
                            }
                        } label: {
                            Text(magicLinkSent ? "Magic link sent — check your mail" : "Email me a magic link")
                                .font(.system(size: 15, weight: .medium))
                                .frame(maxWidth: .infinity)
                        }
                        .foregroundStyle(magicLinkSent ? DT.green : DT.textSecondary)
                        .disabled(email.isEmpty)
                        .padding(.top, 4)

                        if auth.isLoading { ProgressView() }
                        if let error = auth.errorMessage {
                            Text(error)
                                .font(.footnote)
                                .foregroundStyle(DT.vermilion)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.horizontal, DT.Spacing.screenH)
                    .padding(.bottom, 24)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { focused = .email }
        }
    }

    private var canSubmit: Bool {
        !email.isEmpty && password.count >= 6 && !auth.isLoading
    }

    private func signIn() {
        guard canSubmit else { return }
        Task { await auth.signIn(email: email, password: password) }
    }

    private func fieldRow<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .font(.system(size: 17))
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
    }
}

#Preview {
    EmailAuthView().environmentObject(AuthManager())
}
