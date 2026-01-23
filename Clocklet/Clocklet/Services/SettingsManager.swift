//
//  SettingsManager.swift
//  Clocklet
//

import Foundation

enum SettingsKey: String {
    case reminderThresholdMinutes
    case reminderEnabled
    case reminderRepeatMinutes
    case stopOnSleep
    case clockEventNotificationEnabled
}

final class SettingsManager: Sendable {
    static let shared = SettingsManager()

    private let defaults = UserDefaults.standard

    private init() {}

    var reminderThresholdMinutes: Int {
        get { defaults.object(forKey: SettingsKey.reminderThresholdMinutes.rawValue) as? Int ?? 60 }
        set { defaults.set(newValue, forKey: SettingsKey.reminderThresholdMinutes.rawValue) }
    }

    var reminderEnabled: Bool {
        get { defaults.object(forKey: SettingsKey.reminderEnabled.rawValue) as? Bool ?? true }
        set { defaults.set(newValue, forKey: SettingsKey.reminderEnabled.rawValue) }
    }

    var reminderRepeatMinutes: Int? {
        get { defaults.object(forKey: SettingsKey.reminderRepeatMinutes.rawValue) as? Int }
        set { defaults.set(newValue, forKey: SettingsKey.reminderRepeatMinutes.rawValue) }
    }

    var stopOnSleep: Bool {
        get { defaults.object(forKey: SettingsKey.stopOnSleep.rawValue) as? Bool ?? true }
        set { defaults.set(newValue, forKey: SettingsKey.stopOnSleep.rawValue) }
    }

    var clockEventNotificationEnabled: Bool {
        get { defaults.object(forKey: SettingsKey.clockEventNotificationEnabled.rawValue) as? Bool ?? true }
        set { defaults.set(newValue, forKey: SettingsKey.clockEventNotificationEnabled.rawValue) }
    }
}
