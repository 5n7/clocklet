//
//  DailyStatistics.swift
//  Clocklet
//

import Foundation

struct DailyStatistics: Identifiable {
  let id: String
  let year: Int
  let month: Int
  let day: Int
  let totalSeconds: Int

  private let date: Date?

  var displayLabel: String {
    guard let date = date else {
      return "\(month)/\(day)"
    }
    return DateFormatters.shortDate.string(from: date)
  }

  var shortLabel: String {
    "\(day)"
  }

  static func makeKey(year: Int, month: Int, day: Int) -> String {
    "\(year)-\(String(format: "%02d", month))-\(String(format: "%02d", day))"
  }

  init(year: Int, month: Int, day: Int, totalSeconds: Int) {
    self.id = Self.makeKey(year: year, month: month, day: day)
    self.year = year
    self.month = month
    self.day = day
    self.totalSeconds = max(0, totalSeconds)

    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    self.date = Calendar.current.date(from: components)
  }
}
