//
//  TimeEntry.swift
//  Clocklet
//

import Foundation

struct TimeEntry: Codable, Identifiable, Equatable {
    let id: UUID
    var clockIn: Date
    var clockOut: Date
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

    init(clockIn: Date, clockOut: Date) throws {
        guard clockOut > clockIn else {
            throw TimeEntryError.clockOutBeforeClockIn
        }
        self.id = UUID()
        self.clockIn = clockIn
        self.clockOut = clockOut
        self.createdAt = Date()
        self.modifiedAt = nil
    }

    /// For editing existing entries
    mutating func update(clockIn: Date, clockOut: Date) throws {
        guard clockOut > clockIn else {
            throw TimeEntryError.clockOutBeforeClockIn
        }
        self.clockIn = clockIn
        self.clockOut = clockOut
        self.modifiedAt = Date()
    }

    // Custom Codable to handle computed properties
    private enum CodingKeys: String, CodingKey {
        case id, clockIn, clockOut, createdAt, modifiedAt
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
