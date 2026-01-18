//
//  MenuBarView.swift
//  Clocklet
//

import SwiftUI

struct MenuBarView: View {
    @Bindable var viewModel: ClockViewModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Clock In/Out Button
            Button(action: { viewModel.toggle() }) {
                HStack {
                    Image(systemName: viewModel.isTracking ? "stop.circle.fill" : "play.circle.fill")
                        .foregroundColor(viewModel.isTracking ? .green : .secondary)
                    Text(viewModel.isTracking ? "Clock Out" : "Clock In")
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()
                .padding(.vertical, 4)

            // Today's duration
            HStack {
                Text("Today:")
                    .foregroundColor(.secondary)
                Spacer()
                Text(DurationFormatter.format(viewModel.todayDuration))
                    .monospacedDigit()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)

            // This month's duration
            HStack {
                Text("This Month:")
                    .foregroundColor(.secondary)
                Spacer()
                Text(DurationFormatter.format(viewModel.thisMonthDuration))
                    .monospacedDigit()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)

            // Current session info (if tracking)
            if viewModel.isTracking, let session = viewModel.data.currentSession {
                HStack {
                    Text("Started:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(DateFormatters.timeOnly.string(from: session.clockIn))
                        .monospacedDigit()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }

            Divider()
                .padding(.vertical, 4)

            // History
            Button(action: {
                openWindow(id: "history")
                NSApp.activate(ignoringOtherApps: true)
            }) {
                HStack {
                    Text("History")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            // Settings
            Button(action: {
                openSettings()
                NSApp.activate(ignoringOtherApps: true)
            }) {
                HStack {
                    Text("Settings")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()
                .padding(.vertical, 4)

            // Quit
            Button(action: { NSApplication.shared.terminate(nil) }) {
                Text("Quit")
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 200)
        .padding(.vertical, 8)
    }
}
