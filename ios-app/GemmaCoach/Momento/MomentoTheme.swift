// MomentoTheme.swift
// Design tokens for the Momento "Liquid Glass" frontend.
// Ported 1:1 from design_handoff_momento/glass-styles.css (Okabe-Ito palette).
// Colors, spacing, radii, the hex initializer, and the ambient backdrops all
// live here so every screen reads from a single source of truth.

import SwiftUI

// MARK: - Color(hex:)

extension Color {
    /// Hex string ("E48700", "#0B0B0F", "0072B2") → Color. Falls back to clear.
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: s).scanHexInt64(&rgb)
        let r, g, b, a: Double
        switch s.count {
        case 8: // RRGGBBAA
            r = Double((rgb >> 24) & 0xFF) / 255
            g = Double((rgb >> 16) & 0xFF) / 255
            b = Double((rgb >> 8) & 0xFF) / 255
            a = Double(rgb & 0xFF) / 255
        default: // RRGGBB
            r = Double((rgb >> 16) & 0xFF) / 255
            g = Double((rgb >> 8) & 0xFF) / 255
            b = Double(rgb & 0xFF) / 255
            a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

// MARK: - Design tokens

enum DT {
    // Text ramp (dark-on-light). Tinted to match the CSS rgba(60,60,67,·) tones.
    static let textPrimary   = Color(hex: "0B0B0F")
    static let textSecondary = Color(red: 60/255, green: 60/255, blue: 67/255).opacity(0.78)
    static let textTertiary  = Color(red: 60/255, green: 60/255, blue: 67/255).opacity(0.55)
    static let textQuat      = Color(red: 60/255, green: 60/255, blue: 67/255).opacity(0.28)
    static let hairline      = Color(red: 60/255, green: 60/255, blue: 67/255).opacity(0.12)
    static let hairlineStrong = Color(red: 60/255, green: 60/255, blue: 67/255).opacity(0.22)

    // Okabe-Ito accents (colorblind-safe — do not substitute).
    static let accent    = Color(hex: "E48700")  // warm orange — once per screen
    static let blue      = Color(hex: "0072B2")
    static let green     = Color(hex: "009E73")
    static let vermilion = Color(hex: "D55E00")

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 14
        static let lg: CGFloat = 22
        static let xl: CGFloat = 28
        static let screenH: CGFloat = 20   // horizontal screen padding
    }

    enum Radius {
        static let sm: CGFloat = 12
        static let md: CGFloat = 18
        static let lg: CGFloat = 26
        static let xl: CGFloat = 36
        static let capsule: CGFloat = 999
    }
}

// MARK: - Backdrops (ambient gradient blobs behind every screen)

enum BackdropStyle {
    case dawn   // warm peach   — Sign in, Home, Metric detail
    case mist   // cool lavender— Onboarding, History, Settings
    case mint   // cool green   — spare
}

/// Radial gradient blobs over a base linear gradient. Gives the glass material
/// something to refract. Place at the bottom of a screen's ZStack.
struct Backdrop: View {
    let style: BackdropStyle

    var body: some View {
        ZStack {
            base
            ForEach(Array(blobs.enumerated()), id: \.offset) { _, blob in
                RadialGradient(colors: [blob.color, .clear],
                               center: blob.center,
                               startRadius: 0,
                               endRadius: blob.radius)
                    .blur(radius: 60)
            }
        }
        .ignoresSafeArea()
    }

    private struct Blob { let color: Color; let center: UnitPoint; let radius: CGFloat }

    private var base: LinearGradient {
        switch style {
        case .dawn:
            return LinearGradient(colors: [Color(hex: "FCE8D2"), Color(hex: "F4D8C0")],
                                  startPoint: .top, endPoint: .bottom)
        case .mist:
            return LinearGradient(colors: [Color(hex: "F0EFF5"), Color(hex: "E0E1EA")],
                                  startPoint: .top, endPoint: .bottom)
        case .mint:
            return LinearGradient(colors: [Color(hex: "E8F5EE"), Color(hex: "D3E9DD")],
                                  startPoint: .top, endPoint: .bottom)
        }
    }

    private var blobs: [Blob] {
        switch style {
        case .dawn:
            return [
                .init(color: Color(hex: "FFD9A8"), center: .topLeading,  radius: 480),
                .init(color: Color(hex: "FFAA66"), center: .topTrailing, radius: 440),
                .init(color: Color(hex: "F0C8B0"), center: .bottom,      radius: 520),
            ]
        case .mist:
            return [
                .init(color: Color(hex: "E8E4F2"), center: .topLeading,     radius: 440),
                .init(color: Color(hex: "D8E0EE"), center: .bottomTrailing, radius: 480),
            ]
        case .mint:
            return [
                .init(color: Color(hex: "D6EFE3"), center: .topTrailing, radius: 440),
                .init(color: Color(hex: "C0E2D5"), center: .bottomLeading, radius: 520),
            ]
        }
    }
}

// MARK: - Typography helpers

extension View {
    /// 11pt semibold, +12% tracking, uppercase — the "eyebrow" label style.
    func eyebrowStyle() -> some View {
        self.font(.system(size: 11, weight: .semibold))
            .tracking(1.3)
            .textCase(.uppercase)
            .foregroundStyle(DT.textTertiary)
    }
}
