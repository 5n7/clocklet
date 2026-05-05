//
//  CurrentSession.swift
//  Clocklet
//

import Foundation

struct CurrentSession: Codable, Equatable {
  let clockIn: Date
  let jobName: String
  let hourlyRate: Int

  var earnings: Int {
    EarningsCalculator.calculate(
      hourlyRate: hourlyRate,
      durationSeconds: Date().timeIntervalSince(clockIn)
    )
  }

  init(clockIn: Date, jobName: String, hourlyRate: Int) {
    self.clockIn = clockIn
    self.jobName = JobProfile.committedName(jobName)
    self.hourlyRate = max(0, hourlyRate)
  }

  private enum CodingKeys: String, CodingKey {
    case clockIn, jobName, hourlyRate
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    clockIn = try container.decode(Date.self, forKey: .clockIn)
    jobName = JobProfile.committedName(try container.decodeIfPresent(String.self, forKey: .jobName) ?? JobProfile.defaultJobName)
    hourlyRate = max(0, try container.decodeIfPresent(Int.self, forKey: .hourlyRate) ?? SettingsManager.shared.hourlyRate)
  }
}
