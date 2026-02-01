//
//  MonthlyStatistics.swift
//  Clocklet
//

import Foundation

struct MonthlyStatistics: Identifiable {
    let id: String
    let year: Int
    let month: Int
    let totalSeconds: Int

    var totalDuration: TimeInterval {
        TimeInterval(totalSeconds)
    }

    var totalHours: Double {
        Double(totalSeconds) / 3600.0
    }

    private var date: Date? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        return Calendar.current.date(from: components)
    }

    var displayLabel: String {
        guard let date = date else {
            return "\(month)/\(year)"
        }
        return DateFormatters.monthYear.string(from: date)
    }

    var shortLabel: String {
        guard let date = date else {
            return "\(month)"
        }
        return DateFormatters.shortMonth.string(from: date)
    }

    static func makeKey(year: Int, month: Int) -> String {
        "\(year)-\(String(format: "%02d", month))"
    }

    init(year: Int, month: Int, totalSeconds: Int) {
        self.id = Self.makeKey(year: year, month: month)
        self.year = year
        self.month = month
        self.totalSeconds = max(0, totalSeconds)
    }
}
