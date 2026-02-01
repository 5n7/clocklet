//
//  ClockletApp.swift
//  Clocklet
//

import KeyboardShortcuts
import SwiftUI

@main
struct ClockletApp: App {
    private var viewModel: ClockViewModel { ClockViewModel.shared }

    init() {
        // Setup global keyboard shortcut
        KeyboardShortcuts.onKeyUp(for: .toggleClock) {
            Task { @MainActor in
                ClockViewModel.shared.toggle()
            }
        }
    }

    var body: some Scene {
        // Menu Bar
        MenuBarExtra {
            MenuBarView(viewModel: viewModel)
        } label: {
            Image(systemName: viewModel.isTracking ? "clock.fill" : "clock")
                .symbolRenderingMode(.hierarchical)
                .foregroundColor(viewModel.isTracking ? .green : .primary)
        }
        .menuBarExtraStyle(.window)

        // Settings Window
        Settings {
            SettingsView()
        }

        // History Window
        Window("History", id: "history") {
            HistoryView(viewModel: viewModel)
        }
        .defaultSize(width: 500, height: 400)

        // Statistics Window
        Window("Statistics", id: "statistics") {
            StatisticsView(viewModel: viewModel)
        }
        .defaultSize(width: 600, height: 450)
    }
}
