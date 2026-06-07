//
//  EditEntryView.swift
//  Clocklet
//

import SwiftUI

struct EditEntryView: View {
  enum Mode {
    case add
    case edit(TimeEntry)

    var title: String {
      switch self {
      case .add: return "Add Entry"
      case .edit: return "Edit Entry"
      }
    }
  }

  let mode: Mode
  let onSave: (Date, Date, String, Int) -> Void

  @Environment(\.dismiss) private var dismiss

  @State private var clockIn: Date
  @State private var clockOut: Date
  @State private var jobName: String
  @State private var hourlyRateText: String
  @State private var showError = false
  @State private var errorMessage = ""

  init(mode: Mode, onSave: @escaping (Date, Date, String, Int) -> Void) {
    self.mode = mode
    self.onSave = onSave

    switch mode {
    case .add:
      let now = Date()
      _clockIn = State(initialValue: now.addingTimeInterval(-3600))  // 1 hour ago
      _clockOut = State(initialValue: now)
      _jobName = State(initialValue: SettingsManager.shared.currentJobName)
      _hourlyRateText = State(initialValue: SettingsManager.shared.hourlyRate > 0 ? "\(SettingsManager.shared.hourlyRate)" : "")
    case .edit(let entry):
      _clockIn = State(initialValue: entry.clockIn)
      _clockOut = State(initialValue: entry.clockOut)
      _jobName = State(initialValue: entry.jobName)
      _hourlyRateText = State(initialValue: entry.hourlyRate > 0 ? "\(entry.hourlyRate)" : "")
    }
  }

  var body: some View {
    VStack(spacing: 20) {
      Text(mode.title)
        .font(.headline)

      Form {
        TextField("Job", text: $jobName, prompt: Text(JobProfile.defaultJobName))
          .onChange(of: jobName) { _, newValue in
            syncRateForJobName(newValue)
          }

        HStack {
          Text("Rate")
          Spacer()
          Text("¥")
            .foregroundColor(.secondary)
          TextField("", text: $hourlyRateText, prompt: Text("0"))
            .monospacedDigit()
            .frame(width: 80)
            .multilineTextAlignment(.trailing)
            .textFieldStyle(.roundedBorder)
            .onChange(of: hourlyRateText) { _, newValue in
              hourlyRateText = Self.filteredRateText(newValue)
            }
          Text("/ hour")
            .foregroundColor(.secondary)
        }

        DatePicker("Clock In", selection: $clockIn)
        DatePicker("Clock Out", selection: $clockOut)

        if clockOut > clockIn {
          HStack {
            Text("Duration")
            Spacer()
            Text(DurationFormatter.format(Int(clockOut.timeIntervalSince(clockIn))))
              .foregroundColor(.secondary)
          }

          HStack {
            Text("Earnings")
            Spacer()
            Text(
              EarningsCalculator.format(
                EarningsCalculator.calculate(
                  hourlyRate: Int(hourlyRateText) ?? 0,
                  durationSeconds: clockOut.timeIntervalSince(clockIn)
                )
              )
            )
            .foregroundColor(.orange)
          }
        }
      }
      .formStyle(.grouped)

      HStack {
        Button("Cancel") {
          dismiss()
        }
        .keyboardShortcut(.escape)

        Spacer()

        Button("Save") {
          if clockOut <= clockIn {
            errorMessage = "Clock Out must be after Clock In"
            showError = true
          } else {
            onSave(clockIn, clockOut, jobName, Int(hourlyRateText) ?? 0)
            dismiss()
          }
        }
        .keyboardShortcut(.return)
        .buttonStyle(.borderedProminent)
      }
    }
    .padding()
    .frame(width: 380, height: 390)
    .alert("Error", isPresented: $showError) {
      Button("OK") {}
    } message: {
      Text(errorMessage)
    }
  }

  private static func filteredRateText(_ value: String) -> String {
    let filtered = value.filter { $0.isNumber }
    guard !filtered.isEmpty else { return "" }
    return "\(JobProfile.clampRate(Int(filtered) ?? 0))"
  }

  private func syncRateForJobName(_ name: String) {
    let committedName = JobProfile.committedName(name)
    guard case .add = mode,
      let profile = SettingsManager.shared.jobProfiles.first(where: {
        JobProfile.committedName($0.name) == committedName
      })
    else {
      return
    }

    hourlyRateText = profile.hourlyRate > 0 ? "\(profile.hourlyRate)" : ""
  }
}
