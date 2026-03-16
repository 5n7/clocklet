//
//  EarningsCalculator.swift
//  Clocklet
//

import Foundation

enum EarningsCalculator {
  private static let currencyFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.groupingSeparator = ","
    return formatter
  }()

  /// Calculate earnings based on Japanese labor law (minute-level precision)
  /// Seconds are truncated to whole minutes before calculation (切り捨て)
  /// Formula: hourly_rate × (total_minutes / 60)
  static func calculate(hourlyRate: Int, durationSeconds: TimeInterval) -> Int {
    guard hourlyRate > 0, durationSeconds > 0 else { return 0 }
    let totalMinutes = Int(durationSeconds) / 60
    let earnings = Double(hourlyRate) * (Double(totalMinutes) / 60.0)
    return Int(earnings)
  }

  /// Format earnings with yen symbol and comma separators (e.g., "¥ 5,250")
  static func format(_ amount: Int) -> String {
    let formatted = currencyFormatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    return "¥\u{2009}\(formatted)"  // thin space between ¥ and number
  }

}
