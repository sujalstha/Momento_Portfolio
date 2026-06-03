// Secrets.example.swift  —  COMMITTED TEMPLATE (not compiled; lives outside the
// GemmaCoach/ source path on purpose).
//
// Copy this to GemmaCoach/Services/Secrets.swift and fill in the values.
// Secrets.swift is git-ignored because it holds the Cartesia API key.
//
// The Supabase publishable key + Google client IDs below are public-safe.
// The Cartesia key is a real secret — use a STANDARD (TTS-scope) key here,
// NOT an admin key, and never commit it.

import Foundation

// Fill these in your local (git-ignored) Secrets.swift. Values come from the
// Supabase dashboard (Settings → API) and Google Cloud Console (OAuth clients).
enum AuthSecrets {
    static let supabaseURL = URL(string: "https://YOUR-PROJECT.supabase.co")!
    static let supabaseAnonKey = "PASTE_SUPABASE_PUBLISHABLE_ANON_KEY"
    static let googleIOSClientID = "PASTE_GOOGLE_IOS_CLIENT_ID.apps.googleusercontent.com"
    static let googleServerClientID = "PASTE_GOOGLE_WEB_CLIENT_ID.apps.googleusercontent.com"
    static let appRedirectURL = URL(string: "Momento://login-callback")!
    static let appURLScheme = "Momento"
}

enum CartesiaConfig {
    // ⚠️ Paste a STANDARD Cartesia TTS key here (sk_car_...), NOT an admin key.
    static let apiKey   = "sk_car_PASTE_YOUR_REAL_KEY_HERE"
    static let modelID  = "sonic-3.5"
    static let voiceID  = "0ad65e7f-006c-47cf-bd31-52279d487913"   // rupert – caring dad
    static let version  = "2026-03-01"
    static let language = "en"
    static let sampleRate = 44100
    static let endpoint = URL(string: "https://api.cartesia.ai/tts/bytes")!

    static var isConfigured: Bool {
        apiKey.hasPrefix("sk_car_")
            && !apiKey.contains("PASTE_YOUR")
            && apiKey.allSatisfy { $0.isASCII }
            && apiKey.count > 12
    }
}
