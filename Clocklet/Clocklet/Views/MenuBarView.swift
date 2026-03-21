//
//  MenuBarView.swift
//  Clocklet
//

import AppKit
import SwiftUI

private struct ArrowCursorView: NSViewRepresentable {
  func makeNSView(context: Context) -> NSView {
    let view = CursorNSView()
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {}

  private class CursorNSView: NSView {
    override func resetCursorRects() {
      super.resetCursorRects()
      addCursorRect(bounds, cursor: .arrow)
    }
  }
}

/// Menu-style row with hover highlight
private struct MenuRow<Content: View>: View {
  let action: () -> Void
  @ViewBuilder let content: Content
  @State private var isHovering = false

  var body: some View {
    Button(action: action) {
      content
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .background(
      RoundedRectangle(cornerRadius: 4)
        .fill(isHovering ? Color.accentColor.opacity(0.1) : Color.clear)
    )
    .padding(.horizontal, 4)
    .onHover { hovering in
      isHovering = hovering
    }
  }
}

struct MenuBarView: View {
  @Bindable var viewModel: ClockViewModel
  @Environment(\.openWindow) private var openWindow
  @Environment(\.openSettings) private var openSettings

  private var showEarnings: Bool { SettingsManager.shared.isEarningsEnabled }

  var body: some View {
    TimelineView(.periodic(from: .now, by: 1.0)) { _ in
      menuContent
    }
  }

  private var menuContent: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Clock In/Out Button
      MenuRow(action: { viewModel.toggle() }) {
        HStack(spacing: 8) {
          Image(systemName: viewModel.isTracking ? "stop.circle.fill" : "play.circle.fill")
            .foregroundColor(viewModel.isTracking ? .green : .secondary)
            .font(.body)
          Text(viewModel.isTracking ? "Clock Out" : "Clock In")
            .fontWeight(.medium)
          Spacer()
        }
      }

      Divider()
        .padding(.vertical, 4)
        .padding(.horizontal, 8)

      // Duration rows
      durationRow(label: "Today:", duration: viewModel.todayDuration)
      durationRow(label: "This Month:", duration: viewModel.thisMonthDuration)
      durationRow(label: "Last Month:", duration: viewModel.lastMonthDuration)

      // Current session info
      if viewModel.isTracking, let session = viewModel.data.currentSession {
        HStack {
          Text("Started:")
            .foregroundColor(.secondary)
          Spacer()
          Text(DateFormatters.timeOnly.string(from: session.clockIn))
            .monospacedDigit()
        }
        .font(.callout)
        .padding(.horizontal, 16)
        .padding(.vertical, 3)
      }

      Divider()
        .padding(.vertical, 4)
        .padding(.horizontal, 8)

      // Navigation rows
      MenuRow(action: {
        openWindow(id: "history")
        NSApp.activate(ignoringOtherApps: true)
      }) {
        HStack {
          Text("History")
          Spacer()
          Image(systemName: "chevron.right")
            .font(.caption)
            .foregroundColor(.secondary.opacity(0.6))
        }
      }

      MenuRow(action: {
        openWindow(id: "statistics")
        NSApp.activate(ignoringOtherApps: true)
      }) {
        HStack {
          Text("Statistics")
          Spacer()
          Image(systemName: "chevron.right")
            .font(.caption)
            .foregroundColor(.secondary.opacity(0.6))
        }
      }

      MenuRow(action: {
        openSettings()
        NSApp.activate(ignoringOtherApps: true)
      }) {
        HStack {
          Text("Settings")
          Spacer()
          Image(systemName: "chevron.right")
            .font(.caption)
            .foregroundColor(.secondary.opacity(0.6))
        }
      }

      Divider()
        .padding(.vertical, 4)
        .padding(.horizontal, 8)

      MenuRow(action: { NSApplication.shared.terminate(nil) }) {
        Text("Quit")
      }
    }
    .frame(width: 230)
    .padding(.vertical, 6)
    .background(ArrowCursorView())
  }

  private func durationRow(label: String, duration: TimeInterval) -> some View {
    HStack(alignment: .top) {
      Text(label)
        .foregroundColor(.secondary)
      Spacer()
      VStack(alignment: .trailing, spacing: 2) {
        Text(DurationFormatter.format(duration))
          .monospacedDigit()
        if showEarnings {
          Text(
            EarningsCalculator.format(
              EarningsCalculator.calculate(
                hourlyRate: SettingsManager.shared.hourlyRate,
                durationSeconds: duration
              )
            )
          )
          .font(.caption)
          .foregroundColor(.orange)
          .monospacedDigit()
        }
      }
    }
    .font(.callout)
    .padding(.horizontal, 16)
    .padding(.vertical, 3)
  }
}
