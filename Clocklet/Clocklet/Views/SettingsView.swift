//
//  SettingsView.swift
//  Clocklet
//

import AppKit
import KeyboardShortcuts
import LaunchAtLogin
import SwiftUI

extension KeyboardShortcuts.Name {
  static let toggleClock = Self("toggleClock")
}

struct SettingsView: View {
  @State private var reminderEnabled = SettingsManager.shared.reminderEnabled
  @State private var reminderThreshold = SettingsManager.shared.reminderThresholdMinutes
  @State private var reminderRepeat: Int = SettingsManager.shared.reminderRepeatMinutes ?? 0
  @State private var stopOnSleep = SettingsManager.shared.stopOnSleep
  @State private var clockEventNotificationEnabled = SettingsManager.shared
    .clockEventNotificationEnabled
  @State private var notificationSound = SettingsManager.shared.notificationSound
  @State private var hourlyRateEnabled = SettingsManager.shared.hourlyRateEnabled
  @State private var jobProfiles = SettingsManager.shared.jobProfiles
  @State private var selectedJobProfileID = SettingsManager.shared.selectedJobProfileID

  private let thresholdOptions = [15, 30, 45, 60, 90, 120, 180, 240, 300, 360, 480]
  private let repeatOptions = [0, 15, 30, 60]  // 0 = off

  var body: some View {
    Form {
      // Shortcut Section
      Section("Shortcut") {
        KeyboardShortcuts.Recorder("Toggle Clock In/Out:", name: .toggleClock)
      }

      // Reminder Section
      Section("Reminder") {
        Toggle("Enable Reminder", isOn: $reminderEnabled)
          .onChange(of: reminderEnabled) { _, newValue in
            SettingsManager.shared.reminderEnabled = newValue
          }

        if reminderEnabled {
          Picker("Remind after", selection: $reminderThreshold) {
            ForEach(thresholdOptions, id: \.self) { minutes in
              Text(formatMinutes(minutes)).tag(minutes)
            }
          }
          .onChange(of: reminderThreshold) { _, newValue in
            SettingsManager.shared.reminderThresholdMinutes = newValue
          }

          Picker("Repeat", selection: $reminderRepeat) {
            Text("Off").tag(0)
            ForEach(repeatOptions.filter { $0 > 0 }, id: \.self) { minutes in
              Text("Every \(formatMinutes(minutes))").tag(minutes)
            }
          }
          .onChange(of: reminderRepeat) { _, newValue in
            SettingsManager.shared.reminderRepeatMinutes = newValue == 0 ? nil : newValue
          }
        }
      }

      // Jobs Section
      Section("Jobs") {
        Toggle("Enable earnings display", isOn: $hourlyRateEnabled)
          .onChange(of: hourlyRateEnabled) { _, newValue in
            SettingsManager.shared.hourlyRateEnabled = newValue
          }

        Picker("Current Job", selection: $selectedJobProfileID) {
          ForEach(jobProfiles) { job in
            Text(job.name).tag(job.id)
          }
        }
        .onChange(of: selectedJobProfileID) { _, newValue in
          SettingsManager.shared.selectedJobProfileID = newValue
        }

        ForEach(jobProfiles) { job in
          HStack {
            TextField("Job", text: jobNameBinding(for: job.id))
              .textFieldStyle(.roundedBorder)
              .onSubmit {
                commitJobName(id: job.id)
              }

            Spacer()

            Text("¥")
              .foregroundColor(.secondary)

            TextField("0", value: hourlyRateBinding(for: job.id), format: .number)
              .monospacedDigit()
              .frame(width: 80)
              .multilineTextAlignment(.trailing)
              .textFieldStyle(.roundedBorder)

            Text("/ hour")
              .foregroundColor(.secondary)

            Button {
              moveJob(job, by: -1)
            } label: {
              Image(systemName: "chevron.up")
            }
            .buttonStyle(.borderless)
            .disabled(!canMoveJob(job, by: -1))

            Button {
              moveJob(job, by: 1)
            } label: {
              Image(systemName: "chevron.down")
            }
            .buttonStyle(.borderless)
            .disabled(!canMoveJob(job, by: 1))

            Button(role: .destructive) {
              deleteJob(job)
            } label: {
              Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .disabled(jobProfiles.count <= 1)
          }
        }

        Button {
          let profile = SettingsManager.shared.addJobProfile()
          jobProfiles = SettingsManager.shared.jobProfiles
          selectedJobProfileID = profile.id
        } label: {
          Label("Add Job", systemImage: "plus")
        }
      }

      // Behavior Section
      Section("Behavior") {
        Toggle("Notify on Clock In/Out", isOn: $clockEventNotificationEnabled)
          .onChange(of: clockEventNotificationEnabled) { _, newValue in
            SettingsManager.shared.clockEventNotificationEnabled = newValue
          }

        HStack {
          Picker("Notification sound", selection: $notificationSound) {
            ForEach(NotificationSound.allCases) { sound in
              Text(sound.displayName).tag(sound)
            }
          }
          .onChange(of: notificationSound) { _, newValue in
            SettingsManager.shared.notificationSound = newValue
          }

          Button("Play") {
            playNotificationSoundPreview()
          }
          .disabled(notificationSound == .none)
        }

        Toggle("Stop tracking on sleep", isOn: $stopOnSleep)
          .onChange(of: stopOnSleep) { _, newValue in
            SettingsManager.shared.stopOnSleep = newValue
          }

        LaunchAtLogin.Toggle("Launch at login")
      }

      // About Section
      Section("About") {
        HStack {
          Text("Version")
          Spacer()
          Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
            .foregroundColor(.secondary)
        }
      }
    }
    .formStyle(.grouped)
    .frame(width: 460, height: 560)
    .onAppear {
      refreshSettingsState()
    }
    .onDisappear {
      commitJobNames()
    }
  }

  private func jobNameBinding(for id: JobProfile.ID) -> Binding<String> {
    Binding {
      jobProfiles.first { $0.id == id }?.name ?? ""
    } set: { newValue in
      updateLocalJob(id: id) { job in
        job = JobProfile(id: job.id, name: newValue, hourlyRate: job.hourlyRate)
      }
    }
  }

  private func hourlyRateBinding(for id: JobProfile.ID) -> Binding<Int> {
    Binding {
      jobProfiles.first { $0.id == id }?.hourlyRate ?? 0
    } set: { newValue in
      updateLocalJob(id: id) { job in
        job = JobProfile(id: job.id, name: job.name, hourlyRate: min(max(0, newValue), 1_000_000))
      }
    }
  }

  private func refreshSettingsState() {
    hourlyRateEnabled = SettingsManager.shared.hourlyRateEnabled
    jobProfiles = SettingsManager.shared.jobProfiles
    selectedJobProfileID = SettingsManager.shared.selectedJobProfileID
  }

  private func updateLocalJob(id: JobProfile.ID, update: (inout JobProfile) -> Void) {
    guard let index = jobProfiles.firstIndex(where: { $0.id == id }) else { return }
    update(&jobProfiles[index])
    SettingsManager.shared.updateJobProfile(jobProfiles[index])
  }

  private func commitJobName(id: JobProfile.ID) {
    updateLocalJob(id: id) { job in
      job = JobProfile(
        id: job.id,
        name: JobProfile.committedName(job.name),
        hourlyRate: job.hourlyRate
      )
    }
  }

  private func commitJobNames() {
    for job in jobProfiles {
      commitJobName(id: job.id)
    }
  }

  private func canMoveJob(_ job: JobProfile, by offset: Int) -> Bool {
    guard let index = jobProfiles.firstIndex(where: { $0.id == job.id }) else { return false }
    return jobProfiles.indices.contains(index + offset)
  }

  private func moveJob(_ job: JobProfile, by offset: Int) {
    guard let index = jobProfiles.firstIndex(where: { $0.id == job.id }) else { return }
    let destination = index + offset
    guard jobProfiles.indices.contains(destination) else { return }

    jobProfiles.swapAt(index, destination)
    SettingsManager.shared.jobProfiles = jobProfiles
    selectedJobProfileID = SettingsManager.shared.selectedJobProfileID
  }

  private func deleteJob(_ job: JobProfile) {
    SettingsManager.shared.deleteJobProfile(id: job.id)
    jobProfiles = SettingsManager.shared.jobProfiles
    selectedJobProfileID = SettingsManager.shared.selectedJobProfileID
  }

  private func formatMinutes(_ minutes: Int) -> String {
    if minutes >= 60 {
      let hours = minutes / 60
      let mins = minutes % 60
      if mins == 0 {
        return "\(hours)h"
      } else {
        return "\(hours)h \(mins)m"
      }
    } else {
      return "\(minutes)m"
    }
  }

  private func playNotificationSoundPreview() {
    switch notificationSound {
    case .default:
      NSSound.beep()
    case .none:
      break
    default:
      NSSound(named: NSSound.Name(notificationSound.rawValue))?.play()
    }
  }
}
