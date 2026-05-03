//
//  SettingsManager.swift
//  Clocklet
//

import Foundation

enum SettingsKey: String {
  case reminderEnabled
  case reminderThresholdMinutes
  case reminderRepeatMinutes
  case clockEventNotificationEnabled
  case notificationSound
  case stopOnSleep
  case hourlyRateEnabled
  case hourlyRate
}

enum NotificationSound: String, CaseIterable, Identifiable {
  case `default`
  case none
  case basso = "Basso"
  case blow = "Blow"
  case bottle = "Bottle"
  case frog = "Frog"
  case funk = "Funk"
  case glass = "Glass"
  case hero = "Hero"
  case morse = "Morse"
  case ping = "Ping"
  case pop = "Pop"
  case purr = "Purr"
  case sosumi = "Sosumi"
  case submarine = "Submarine"
  case tink = "Tink"

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .default:
      return "Default"
    case .none:
      return "None"
    default:
      return rawValue
    }
  }
}

final class SettingsManager: Sendable {
  static let shared = SettingsManager()

  private let defaults = UserDefaults.standard

  private init() {}

  var reminderEnabled: Bool {
    get { defaults.object(forKey: SettingsKey.reminderEnabled.rawValue) as? Bool ?? true }
    set { defaults.set(newValue, forKey: SettingsKey.reminderEnabled.rawValue) }
  }

  var reminderThresholdMinutes: Int {
    get { defaults.object(forKey: SettingsKey.reminderThresholdMinutes.rawValue) as? Int ?? 60 }
    set { defaults.set(newValue, forKey: SettingsKey.reminderThresholdMinutes.rawValue) }
  }

  var reminderRepeatMinutes: Int? {
    get { defaults.object(forKey: SettingsKey.reminderRepeatMinutes.rawValue) as? Int }
    set { defaults.set(newValue, forKey: SettingsKey.reminderRepeatMinutes.rawValue) }
  }

  var clockEventNotificationEnabled: Bool {
    get {
      defaults.object(forKey: SettingsKey.clockEventNotificationEnabled.rawValue) as? Bool ?? true
    }
    set { defaults.set(newValue, forKey: SettingsKey.clockEventNotificationEnabled.rawValue) }
  }

  var notificationSound: NotificationSound {
    get {
      guard let rawValue = defaults.string(forKey: SettingsKey.notificationSound.rawValue) else {
        return .default
      }
      return NotificationSound(rawValue: rawValue) ?? .default
    }
    set { defaults.set(newValue.rawValue, forKey: SettingsKey.notificationSound.rawValue) }
  }

  var stopOnSleep: Bool {
    get { defaults.object(forKey: SettingsKey.stopOnSleep.rawValue) as? Bool ?? true }
    set { defaults.set(newValue, forKey: SettingsKey.stopOnSleep.rawValue) }
  }

  var hourlyRateEnabled: Bool {
    get { defaults.object(forKey: SettingsKey.hourlyRateEnabled.rawValue) as? Bool ?? false }
    set { defaults.set(newValue, forKey: SettingsKey.hourlyRateEnabled.rawValue) }
  }

  var hourlyRate: Int {
    get { defaults.object(forKey: SettingsKey.hourlyRate.rawValue) as? Int ?? 0 }
    set { defaults.set(newValue, forKey: SettingsKey.hourlyRate.rawValue) }
  }

  var isEarningsEnabled: Bool {
    hourlyRateEnabled && hourlyRate > 0
  }
}
