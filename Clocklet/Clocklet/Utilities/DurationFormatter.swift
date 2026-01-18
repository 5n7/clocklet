//
//  DurationFormatter.swift
//  Clocklet
//

import Foundation

enum DurationFormatter {
    /// Format duration in seconds to "Xh Ym" format
    /// e.g., 3600 -> "1h 0m", 5400 -> "1h 30m", 1800 -> "0h 30m"
    static func format(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        return "\(hours)h \(minutes)m"
    }

    /// Format TimeInterval to "Xh Ym" format
    static func format(_ interval: TimeInterval) -> String {
        format(Int(interval))
    }

    /// Format duration in seconds to detailed format
    /// e.g., 3661 -> "1h 1m 1s"
    static func formatDetailed(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m \(secs)s"
        } else if minutes > 0 {
            return "\(minutes)m \(secs)s"
        } else {
            return "\(secs)s"
        }
    }
}
