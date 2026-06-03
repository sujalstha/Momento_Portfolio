// AuthManager.swift
// Supabase auth surface for Momento: email/password, magic link, Sign in with
// Apple, and Google Sign-In. Publishes the current Supabase `Session` so the
// root view can gate the app. Implemented per SUPABASE_INTEGRATION.md.

import Foundation
import SwiftUI
import UIKit
import Supabase
import AuthenticationServices
import GoogleSignIn
import CryptoKit

@MainActor
final class AuthManager: NSObject, ObservableObject {
    @Published var session: Session?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var currentNonce: String?

    override init() {
        super.init()
        Task { await observeAuthState() }
    }

    /// Streams Supabase auth-state changes (sign in, sign out, token refresh,
    /// magic-link callback) into `session` so SwiftUI reacts automatically.
    private func observeAuthState() async {
        for await (event, session) in supabase.auth.authStateChanges {
            self.session = session
            _ = event
        }
    }

    /// Convenience for views: the signed-in user's email, if any.
    var userEmail: String? { session?.user.email }

    // MARK: - Email

    func signUp(email: String, password: String) async {
        await run { try await supabase.auth.signUp(email: email, password: password) }
    }

    func signIn(email: String, password: String) async {
        await run { try await supabase.auth.signIn(email: email, password: password) }
    }

    func sendMagicLink(to email: String) async {
        await run {
            try await supabase.auth.signInWithOTP(
                email: email,
                redirectTo: AuthSecrets.appRedirectURL
            )
        }
    }

    // MARK: - Sign in with Apple

    func handleAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
    }

    func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) async {
        await run {
            guard case .success(let auth) = result,
                  let cred = auth.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = cred.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8),
                  let nonce = self.currentNonce
            else {
                throw NSError(domain: "AuthManager", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "Invalid Apple credential"])
            }
            try await supabase.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(provider: .apple, idToken: idToken, nonce: nonce)
            )
        }
    }

    // MARK: - Google

    func signInWithGoogle() async {
        guard let presenting = Self.topViewController() else {
            errorMessage = "Couldn't find a view controller to present Google Sign-In."
            return
        }
        await run {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenting)
            guard let idToken = result.user.idToken?.tokenString else {
                throw NSError(domain: "AuthManager", code: -2,
                              userInfo: [NSLocalizedDescriptionKey: "No Google ID token"])
            }
            let accessToken = result.user.accessToken.tokenString
            try await supabase.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(provider: .google,
                                                      idToken: idToken,
                                                      accessToken: accessToken)
            )
        }
    }

    // MARK: - Sign out

    func signOut() async {
        await run { try await supabase.auth.signOut() }
    }

    // MARK: - Helpers

    private func run(_ work: @escaping () async throws -> Void) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do { try await work() }
        catch { errorMessage = error.localizedDescription }
    }

    /// Walks the active scene's key window to the foremost presented controller —
    /// the correct anchor for the Google Sign-In sheet from SwiftUI.
    static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
            ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        var top = scene?.windows.first(where: \.isKeyWindow)?.rootViewController
            ?? scene?.windows.first?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }

    private func randomNonceString(length: Int = 32) -> String {
        let charset: [Character] =
            Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in UInt8.random(in: 0...255) }
            for r in randoms {
                if remaining == 0 { break }
                if r < charset.count {
                    result.append(charset[Int(r)])
                    remaining -= 1
                }
            }
        }
        return result
    }

    private func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
