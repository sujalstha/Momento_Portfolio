// GlassComponents.swift
// Reusable Liquid-Glass primitives for Momento. Each maps to a class in
// glass-styles.css: .glass, .btn-*, .seg, .pill, .orb, .start-cta, .mrow, etc.
// Respects Reduce Transparency (solid fallback) and Reduce Motion (no anim).

import SwiftUI

// MARK: - Glass surface

/// Translucent material surface with a top specular highlight + soft shadow.
/// Swaps to a solid fill when Reduce Transparency is on.
struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = DT.Radius.md
    var strong: Bool = false
    @ViewBuilder var content: () -> Content

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        content()
            .background(background)
            .overlay(specular)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.28), radius: 38, x: 0, y: 18)
            .shadow(color: .black.opacity(0.12), radius: 14, x: 0, y: 6)
    }

    @ViewBuilder private var background: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if reduceTransparency {
            shape.fill(Color(.secondarySystemBackground))
        } else {
            shape.fill(strong ? AnyShapeStyle(.regularMaterial) : AnyShapeStyle(.ultraThinMaterial))
        }
    }

    private var specular: some View {
        LinearGradient(colors: [.white.opacity(0.18), .clear],
                       startPoint: .top, endPoint: .center)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .allowsHitTesting(false)
    }
}

// MARK: - Button styles

enum GlassVariant { case glass, glassStrong, dark }

/// Capsule glass / dark button matching `.btn .btn-lg`. Press = 0.985 scale.
struct GlassButtonStyle: ButtonStyle {
    var variant: GlassVariant = .glass
    var large: Bool = true
    var tint: Color? = nil

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: large ? 18 : 17, weight: .semibold))
            .frame(maxWidth: .infinity)
            .frame(minHeight: large ? 58 : 52)
            .padding(.horizontal, 22)
            .foregroundStyle(foreground)
            .background(background)
            .overlay(
                Capsule().strokeBorder(.white.opacity(variant == .dark ? 0.06 : 0.5),
                                       lineWidth: 0.5)
            )
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 8)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
            .contentShape(Capsule())
    }

    private var foreground: Color {
        if let tint { return tint }
        return variant == .dark ? .white : DT.textPrimary
    }

    @ViewBuilder private var background: some View {
        switch variant {
        case .dark:
            Capsule().fill(Color(hex: "0B0B0F"))
        case .glass, .glassStrong:
            if reduceTransparency {
                Capsule().fill(Color(.secondarySystemBackground))
            } else {
                Capsule().fill(variant == .glassStrong
                               ? AnyShapeStyle(.regularMaterial)
                               : AnyShapeStyle(.ultraThinMaterial))
            }
        }
    }
}

// MARK: - Segmented top tabs (Run / History / Settings)

enum MomentoTab: String, CaseIterable, Identifiable {
    case run = "Run", history = "History", settings = "Settings"
    var id: String { rawValue }
}

struct SegmentedTabs: View {
    @Binding var selection: MomentoTab
    @Namespace private var ns
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MomentoTab.allCases) { tab in
                let on = selection == tab
                Text(tab.rawValue)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(on ? DT.textPrimary : DT.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background {
                        if on {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(.white.opacity(0.85))
                                .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                                .matchedGeometryEffect(id: "seg", in: ns)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if reduceMotion { selection = tab }
                        else { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { selection = tab } }
                    }
                    .accessibilityElement()
                    .accessibilityLabel(tab.rawValue)
                    .accessibilityAddTraits(on ? [.isSelected, .isButton] : .isButton)
            }
        }
        .padding(3)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.white.opacity(0.4), lineWidth: 0.5)
        )
    }
}

// MARK: - Pill

struct Pill: View {
    let text: String
    var showDot: Bool = false
    var dotColor: Color = DT.green
    var systemIcon: String? = nil
    var tint: Color = DT.textSecondary
    var fill: Color? = nil

    var body: some View {
        HStack(spacing: 6) {
            if showDot {
                Circle().fill(dotColor).frame(width: 6, height: 6)
            }
            if let systemIcon {
                Image(systemName: systemIcon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(tint)
            }
            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background {
            if let fill {
                Capsule().fill(fill)
            } else {
                Capsule().fill(.ultraThinMaterial)
            }
        }
        .overlay(Capsule().strokeBorder(.black.opacity(0.06), lineWidth: 0.5))
    }
}

// MARK: - The orb (blue gradient sphere)

struct Orb: View {
    var size: CGFloat = 196

    var body: some View {
        Circle()
            .fill(
                RadialGradient(colors: [Color(hex: "6BB6F0"), Color(hex: "2C72B8"), Color(hex: "0C2F5B")],
                               center: UnitPoint(x: 0.7, y: 0.78),
                               startRadius: 0, endRadius: size * 0.95)
            )
            .overlay(
                // top-left specular highlight
                Circle().fill(
                    RadialGradient(colors: [.white.opacity(0.85), .clear],
                                   center: UnitPoint(x: 0.32, y: 0.28),
                                   startRadius: 0, endRadius: size * 0.3)
                )
            )
            .overlay(Circle().strokeBorder(.white.opacity(0.06), lineWidth: 8))
            .frame(width: size, height: size)
            .shadow(color: Color(red: 20/255, green: 50/255, blue: 95/255).opacity(0.5),
                    radius: 30, x: 0, y: 20)
            .accessibilityHidden(true)
    }
}

// MARK: - Voice waveform + pulse ring (onboarding)

struct Waveform: View {
    private let heights: [CGFloat] = [10,18,30,50,40,68,46,28,18,32,52,40,22,12]
    @State private var animate = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(heights.enumerated()), id: \.offset) { i, h in
                Capsule()
                    .fill(DT.textPrimary.opacity(0.85))
                    .frame(width: 4, height: animate && !reduceMotion ? h : h * 0.5)
                    .animation(reduceMotion ? nil :
                        .easeInOut(duration: 0.5)
                        .repeatForever(autoreverses: true)
                        .delay(Double(i) * 0.06),
                        value: animate)
            }
        }
        .frame(height: 68)
        .onAppear { animate = true }
        .accessibilityHidden(true)
    }
}

struct PulseRing: View {
    var diameter: CGFloat
    @State private var animate = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Circle()
            .strokeBorder(Color(red: 11/255, green: 33/255, blue: 70/255).opacity(0.4), lineWidth: 1)
            .frame(width: diameter, height: diameter)
            .scaleEffect(animate && !reduceMotion ? 1.5 : 1)
            .opacity(animate && !reduceMotion ? 0 : 0.65)
            .animation(reduceMotion ? nil :
                .easeOut(duration: 2.5).repeatForever(autoreverses: false),
                value: animate)
            .onAppear { animate = true }
            .accessibilityHidden(true)
    }
}

// MARK: - Start CTA (Home)

struct StartCTA: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "play.fill")
                .font(.system(size: 24))
                .foregroundStyle(DT.accent)
            Text("Start run")
                .font(.system(size: 26, weight: .bold))
                .tracking(-0.5)
                .foregroundStyle(DT.textPrimary)
            Text("Live coach")
                .eyebrowStyle()
        }
        .frame(width: 232, height: 232)
        .background(.regularMaterial, in: Circle())
        .overlay(
            Circle().fill(
                RadialGradient(colors: [.white.opacity(0.5), .clear],
                               center: UnitPoint(x: 0.3, y: 0.25),
                               startRadius: 0, endRadius: 150)
            )
            .allowsHitTesting(false)
        )
        .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 0.5))
        .shadow(color: Color(red: 15/255, green: 20/255, blue: 35/255).opacity(0.3),
                radius: 60, x: 0, y: 30)
    }
}

// MARK: - Metric row (used in Metric detail card)

struct MetricRow: View {
    let label: String
    let value: String
    let unit: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(DT.textPrimary)
            Spacer()
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .monospacedDigit()
                .tracking(-0.4)
                .foregroundStyle(DT.textPrimary)
            Text(unit)
                .font(.system(size: 12, weight: .semibold))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(DT.textTertiary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Settings list row

struct MomentoListRow: View {
    let systemIcon: String
    let title: String
    var value: String? = nil
    var tint: Color = DT.textPrimary

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemIcon)
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(DT.textSecondary)
                .frame(width: 26)
            Text(title)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(tint)
            Spacer(minLength: 8)
            if let value {
                Text(value)
                    .font(.system(size: 16))
                    .foregroundStyle(DT.textSecondary)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DT.textQuat)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(minHeight: 56)
        .contentShape(Rectangle())
    }
}

/// Hairline divider inset from the left edge (matches `.list .item + .item::after`).
struct InsetDivider: View {
    var body: some View {
        Rectangle()
            .fill(DT.hairline)
            .frame(height: 0.5)
            .padding(.leading, 18)
    }
}

/// Wraps rows in the inset-glass list container with hairlines between them.
struct ListContainer<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        GlassCard(cornerRadius: DT.Radius.md) {
            VStack(spacing: 0) { content() }
        }
    }
}
