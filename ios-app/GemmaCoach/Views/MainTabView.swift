// MainTabView.swift
// Authenticated root. Three top-level destinations behind a shared top
// segmented control (Run / History / Settings) — NOT the iOS bottom tab bar.
// Each tab keeps its own NavigationStack for pushes (Metric detail, pickers).

import SwiftUI

struct MainTabView: View {
    @State private var tab: MomentoTab = .run

    var body: some View {
        ZStack {
            // Backdrop swaps per tab to match the design (Run/dawn, others/mist).
            Backdrop(style: tab == .run ? .dawn : .mist)

            VStack(spacing: 0) {
                SegmentedTabs(selection: $tab)
                    .padding(.horizontal, DT.Spacing.screenH)
                    .padding(.top, 8)

                content
            }
        }
    }

    @ViewBuilder private var content: some View {
        switch tab {
        case .run:      HomeRunView()
        case .history:  HistoryView()
        case .settings: SettingsView()
        }
    }
}
