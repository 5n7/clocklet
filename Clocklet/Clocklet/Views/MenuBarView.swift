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

  private var jobProfiles: [JobProfile] { SettingsManager.shared.jobProfiles }
  private var selectedJobProfileID: UUID { SettingsManager.shared.selectedJobProfileID }
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

      jobSwitcher

      Divider()
        .padding(.vertical, 4)
        .padding(.horizontal, 8)

      // Duration rows
      durationRow(
        label: "Today:",
        duration: viewModel.todayDuration,
        earnings: viewModel.todayEarnings
      )
      durationRow(
        label: "This Month:",
        duration: viewModel.thisMonthDuration,
        earnings: viewModel.thisMonthEarnings
      )
      durationRow(
        label: "Last Month:",
        duration: viewModel.lastMonthDuration,
        earnings: viewModel.lastMonthEarnings
      )

      // Current session info
      if viewModel.isTracking, let session = viewModel.data.currentSession {
        HStack {
          Text("Started:")
            .foregroundColor(.secondary)
          Spacer()
          VStack(alignment: .trailing, spacing: 2) {
            Text(DateFormatters.timeOnly.string(from: session.clockIn))
              .monospacedDigit()
            Text(session.jobName)
              .font(.caption)
              .foregroundColor(.secondary)
          }
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
    .frame(width: 260)
    .padding(.vertical, 6)
    .background(ArrowCursorView())
  }

  private var jobSwitcher: some View {
    let label = viewModel.isTracking ? "Next Job:" : "Job:"

    return VStack(alignment: .leading, spacing: 2) {
      Text(label)
        .font(.caption)
        .foregroundColor(.secondary)
        .padding(.horizontal, 16)
        .padding(.bottom, 2)

      ForEach(jobProfiles) { job in
        MenuRow(action: {
          SettingsManager.shared.selectedJobProfileID = job.id
        }) {
          HStack(spacing: 8) {
            Image(systemName: selectedJobProfileID == job.id ? "checkmark.circle.fill" : "circle")
              .foregroundColor(selectedJobProfileID == job.id ? .accentColor : .secondary)

            Text(job.name)
              .lineLimit(1)

            Spacer()

            if showEarnings {
              Text("¥\(job.hourlyRate)/h")
                .font(.caption)
                .foregroundColor(.secondary)
                .monospacedDigit()
            }
          }
        }
      }
    }
  }

  private func durationRow(label: String, duration: TimeInterval, earnings: Int) -> some View {
    HStack(alignment: .top) {
      Text(label)
        .foregroundColor(.secondary)
      Spacer()
      VStack(alignment: .trailing, spacing: 2) {
        Text(DurationFormatter.format(duration))
          .monospacedDigit()
        if showEarnings {
          Text(EarningsCalculator.format(earnings))
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
