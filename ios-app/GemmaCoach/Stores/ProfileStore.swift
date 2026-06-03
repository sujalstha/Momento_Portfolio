// ProfileStore.swift
// User profile + app preferences collected during onboarding and edited in
// Settings. Backed by UserDefaults so it survives relaunch and is readable
// before the SwiftData container spins up.

import Foundation
import SwiftUI

enum UnitSystem: String, CaseIterable, Identifiable {
    case imperial, metric
    var id: String { rawValue }
    var label: String { self == .imperial ? "Imperial" : "Metric" }
    var isImperial: Bool { self == .imperial }
}

@MainActor
final class ProfileStore: ObservableObject {
    @AppStorage("profile.name")        var name: String = ""
    @AppStorage("profile.email")       var email: String = ""
    @AppStorage("profile.ageYears")    var ageYears: Int = 0
    @AppStorage("profile.gender")      var gender: String = ""
    @AppStorage("profile.heightCm")    var heightCm: Double = 0
    @AppStorage("profile.weightKg")    var weightKg: Double = 0
    @AppStorage("profile.units")       private var unitsRaw: String = UnitSystem.imperial.rawValue
    @AppStorage("profile.echoVoice")   var echoVoice: String = "Rupert"
    @AppStorage("profile.hasOnboarded") var hasOnboarded: Bool = false

    var units: UnitSystem {
        get { UnitSystem(rawValue: unitsRaw) ?? .imperial }
        set { unitsRaw = newValue.rawValue; objectWillChange.send() }
    }

    /// First letter for the circular avatar; falls back to "M" (Momento).
    var avatarInitial: String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "M" : String(trimmed.prefix(1)).uppercased()
    }

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "Runner" : trimmed
    }

    /// Greeting first name only — "Ready, Priya?"
    var firstName: String {
        displayName.split(separator: " ").first.map(String.init) ?? displayName
    }

    /// Clears profile + onboarding flag on sign-out.
    func reset() {
        name = ""; email = ""; ageYears = 0; gender = ""
        heightCm = 0; weightKg = 0; hasOnboarded = false
    }
}
