//
//  TimeEntry.swift
//  Clocklet
//

import Foundation

struct TimeEntry: Codable, Identifiable, Equatable {
  let id: UUID
  var clockIn: Date
  var clockOut: Date
  var jobName: String
  var hourlyRate: Int
  let createdAt: Date
  var modifiedAt: Date?

  /// Date string for grouping (derived from clockIn)
  var date: String {
    DateFormatters.dateOnly.string(from: clockIn)
  }

  /// Duration in seconds (computed from clockIn/clockOut)
  var durationSeconds: Int {
    Int(clockOut.timeIntervalSince(clockIn))
  }

  var earnings: Int {
    EarningsCalculator.calculate(hourlyRate: hourlyRate, durationSeconds: TimeInterval(durationSeconds))
  }

  init(clockIn: Date, clockOut: Date, jobName: String, hourlyRate: Int) throws {
    guard clockOut > clockIn else {
      throw TimeEntryError.clockOutBeforeClockIn
    }
    self.id = UUID()
    self.clockIn = clockIn
    self.clockOut = clockOut
    self.jobName = JobProfile.committedName(jobName)
    self.hourlyRate = max(0, hourlyRate)
    self.createdAt = Date()
    self.modifiedAt = nil
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(UUID.self, forKey: .id)
    clockIn = try container.decode(Date.self, forKey: .clockIn)
    clockOut = try container.decode(Date.self, forKey: .clockOut)
    jobName = JobProfile.committedName(try container.decodeIfPresent(String.self, forKey: .jobName) ?? JobProfile.defaultJobName)
    hourlyRate = max(0, try container.decodeIfPresent(Int.self, forKey: .hourlyRate) ?? SettingsManager.shared.hourlyRate)
    createdAt = try container.decode(Date.self, forKey: .createdAt)
    modifiedAt = try container.decodeIfPresent(Date.self, forKey: .modifiedAt)
  }

  /// For editing existing entries
  mutating func update(clockIn: Date, clockOut: Date, jobName: String, hourlyRate: Int) throws {
    guard clockOut > clockIn else {
      throw TimeEntryError.clockOutBeforeClockIn
    }
    self.clockIn = clockIn
    self.clockOut = clockOut
    self.jobName = JobProfile.committedName(jobName)
    self.hourlyRate = max(0, hourlyRate)
    self.modifiedAt = Date()
  }

  private enum CodingKeys: String, CodingKey {
    case id, clockIn, clockOut, jobName, hourlyRate, createdAt, modifiedAt
  }
}

enum TimeEntryError: LocalizedError {
  case clockOutBeforeClockIn

  var errorDescription: String? {
    switch self {
    case .clockOutBeforeClockIn:
      return "Clock Out must be after Clock In"
    }
  }
}
