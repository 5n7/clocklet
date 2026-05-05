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
  case currentJobName
  case jobProfiles
  case selectedJobProfileID
}

struct JobProfile: Codable, Identifiable, Equatable {
  static let defaultJobName = "Work"

  let id: UUID
  var name: String
  var hourlyRate: Int

  init(id: UUID = UUID(), name: String, hourlyRate: Int) {
    self.id = id
    self.name = Self.lenientName(name)
    self.hourlyRate = max(0, min(hourlyRate, 1_000_000))
  }

  static func committedName(_ name: String) -> String {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? defaultJobName : trimmed
  }

  private static func lenientName(_ name: String) -> String {
    name.isEmpty ? defaultJobName : name
  }
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
  private let lock = NSRecursiveLock()
  nonisolated(unsafe) private var cachedProfiles: [JobProfile]?

  private init() {}

  func bootstrap() {
    withLock {
      guard loadStoredJobProfiles() == nil else { return }
      let legacyProfile = JobProfile(name: legacyCurrentJobName, hourlyRate: legacyHourlyRate)
      saveJobProfiles([legacyProfile])
      defaults.set(legacyProfile.id.uuidString, forKey: SettingsKey.selectedJobProfileID.rawValue)
    }
  }

  private var legacyHourlyRate: Int {
    defaults.object(forKey: SettingsKey.hourlyRate.rawValue) as? Int ?? 0
  }

  private var legacyCurrentJobName: String {
    let value = defaults.string(forKey: SettingsKey.currentJobName.rawValue) ?? JobProfile.defaultJobName
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? JobProfile.defaultJobName : trimmed
  }

  private var storedSelectedJobProfileID: UUID? {
    guard let value = defaults.string(forKey: SettingsKey.selectedJobProfileID.rawValue) else {
      return nil
    }
    return UUID(uuidString: value)
  }

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
    get { withLock { selectedJobProfile.hourlyRate } }
    set {
      withLock {
        var job = selectedJobProfile
        job.hourlyRate = max(0, min(newValue, 1_000_000))
        updateJobProfile(job)
      }
    }
  }

  var currentJobName: String {
    get { withLock { selectedJobProfile.name } }
    set {
      withLock {
        var job = selectedJobProfile
        job = JobProfile(id: job.id, name: newValue, hourlyRate: job.hourlyRate)
        updateJobProfile(job)
      }
    }
  }

  var jobProfiles: [JobProfile] {
    get {
      withLock { currentProfiles() }
    }
    set {
      withLock {
        let profiles = newValue.isEmpty ? [JobProfile(name: JobProfile.defaultJobName, hourlyRate: 0)] : newValue
        saveJobProfiles(profiles)
        if !profiles.contains(where: { $0.id == storedSelectedJobProfileID }) {
          defaults.set(profiles[0].id.uuidString, forKey: SettingsKey.selectedJobProfileID.rawValue)
        }
      }
    }
  }

  var selectedJobProfileID: UUID {
    get {
      withLock {
        let profiles = currentProfiles()
        if let id = storedSelectedJobProfileID,
          profiles.contains(where: { $0.id == id })
        {
          return id
        }

        return profiles[0].id
      }
    }
    set {
      withLock {
        guard currentProfiles().contains(where: { $0.id == newValue }) else { return }
        defaults.set(newValue.uuidString, forKey: SettingsKey.selectedJobProfileID.rawValue)
      }
    }
  }

  var selectedJobProfile: JobProfile {
    withLock {
      let profiles = currentProfiles()
      let id: UUID
      if let stored = storedSelectedJobProfileID,
        profiles.contains(where: { $0.id == stored })
      {
        id = stored
      } else {
        id = profiles[0].id
      }
      return profiles.first { $0.id == id } ?? profiles[0]
    }
  }

  func addJobProfile() -> JobProfile {
    withLock {
      let profile = JobProfile(name: "New Job", hourlyRate: 0)
      var profiles = currentProfiles()
      profiles.append(profile)
      saveJobProfiles(profiles)
      defaults.set(profile.id.uuidString, forKey: SettingsKey.selectedJobProfileID.rawValue)
      return profile
    }
  }

  func updateJobProfile(_ profile: JobProfile) {
    withLock {
      var profiles = currentProfiles()
      guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
      profiles[index] = JobProfile(id: profile.id, name: profile.name, hourlyRate: profile.hourlyRate)
      saveJobProfiles(profiles)
    }
  }

  func deleteJobProfile(id: JobProfile.ID) {
    withLock {
      var profiles = currentProfiles()
      guard profiles.count > 1 else { return }
      profiles.removeAll { $0.id == id }
      saveJobProfiles(profiles)
      if !profiles.contains(where: { $0.id == storedSelectedJobProfileID }) {
        defaults.set(profiles[0].id.uuidString, forKey: SettingsKey.selectedJobProfileID.rawValue)
      }
    }
  }

  var isEarningsEnabled: Bool {
    hourlyRateEnabled && jobProfiles.contains { $0.hourlyRate > 0 }
  }

  private func currentProfiles() -> [JobProfile] {
    if let cached = cachedProfiles {
      return cached
    }
    let profiles = loadStoredJobProfiles() ?? [JobProfile(name: legacyCurrentJobName, hourlyRate: legacyHourlyRate)]
    cachedProfiles = profiles
    return profiles
  }

  private func loadStoredJobProfiles() -> [JobProfile]? {
    guard let data = defaults.data(forKey: SettingsKey.jobProfiles.rawValue),
      let profiles = try? JSONDecoder().decode([JobProfile].self, from: data),
      !profiles.isEmpty
    else {
      return nil
    }
    cachedProfiles = profiles
    return profiles
  }

  private func saveJobProfiles(_ profiles: [JobProfile]) {
    guard let data = try? JSONEncoder().encode(profiles) else { return }
    defaults.set(data, forKey: SettingsKey.jobProfiles.rawValue)
    cachedProfiles = profiles
  }

  private func withLock<T>(_ body: () throws -> T) rethrows -> T {
    lock.lock()
    defer { lock.unlock() }
    return try body()
  }
}
