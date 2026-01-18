//
//  SettingsView.swift
//  Clocklet
//

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

    private let thresholdOptions = [15, 30, 45, 60, 90, 120, 180, 240, 300, 360, 480]
    private let repeatOptions = [0, 15, 30, 60] // 0 = off

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

            // Behavior Section
            Section("Behavior") {
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
        .frame(width: 400, height: 350)
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
}
