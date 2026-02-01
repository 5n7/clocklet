//
//  ClockViewModel.swift
//  Clocklet
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class ClockViewModel {
    static let shared = ClockViewModel(
        dataStore: DataStore(),
        notificationManager: NotificationManager()
    )

    private let dataStore: DataStore
    private let notificationManager: NotificationManager
    private let reminderScheduler: ReminderScheduler
    private var sleepWatcher: SleepWatcher?

    private(set) var data: ClockletData = ClockletData()
    private(set) var lastError: Error?

    var isTracking: Bool {
        data.currentSession != nil
    }

    var currentSessionDuration: TimeInterval {
        guard let session = data.currentSession else { return 0 }
        return Date().timeIntervalSince(session.clockIn)
    }

    var todayDuration: TimeInterval {
        let now = Date()
        let today = DateFormatters.dateOnly.string(from: now)
        let completedDuration = data.entries
            .filter { $0.date == today }
            .reduce(0) { $0 + TimeInterval($1.durationSeconds) }

        // Add current session duration if tracking
        if let session = data.currentSession,
           DateFormatters.dateOnly.string(from: session.clockIn) == today {
            return completedDuration + now.timeIntervalSince(session.clockIn)
        }

        return completedDuration
    }

    var thisMonthDuration: TimeInterval {
        let now = Date()
        let calendar = Calendar.current
        let completedDuration = data.entries
            .filter { calendar.isDate($0.clockIn, equalTo: now, toGranularity: .month) }
            .reduce(0) { $0 + TimeInterval($1.durationSeconds) }

        // Add current session duration if tracking
        if let session = data.currentSession,
           calendar.isDate(session.clockIn, equalTo: now, toGranularity: .month) {
            return completedDuration + now.timeIntervalSince(session.clockIn)
        }

        return completedDuration
    }

    var lastMonthDuration: TimeInterval {
        let calendar = Calendar.current
        guard let lastMonth = calendar.date(byAdding: .month, value: -1, to: Date()) else {
            return 0
        }
        return data.entries
            .filter { calendar.isDate($0.clockIn, equalTo: lastMonth, toGranularity: .month) }
            .reduce(0) { $0 + TimeInterval($1.durationSeconds) }
    }

    /// Get monthly statistics for the specified number of months
    func monthlyStatistics(months: Int = 12) -> [MonthlyStatistics] {
        let calendar = Calendar.current
        let now = Date()

        // Create a dictionary to store durations by year-month key
        var durationsByMonth: [String: Int] = [:]

        // Group entries by month
        for entry in data.entries {
            let components = calendar.dateComponents([.year, .month], from: entry.clockIn)
            guard let year = components.year, let month = components.month else { continue }
            let key = MonthlyStatistics.makeKey(year: year, month: month)
            durationsByMonth[key, default: 0] += entry.durationSeconds
        }

        // Generate statistics for the past N months (including current month)
        var statistics: [MonthlyStatistics] = []
        for i in 0..<months {
            guard let date = calendar.date(byAdding: .month, value: -i, to: now) else { continue }
            let components = calendar.dateComponents([.year, .month], from: date)
            guard let year = components.year, let month = components.month else { continue }
            let key = MonthlyStatistics.makeKey(year: year, month: month)
            let totalSeconds = durationsByMonth[key] ?? 0
            statistics.append(MonthlyStatistics(year: year, month: month, totalSeconds: totalSeconds))
        }

        // Reverse to get chronological order (oldest first)
        return statistics.reversed()
    }

    /// Entries grouped by date for history view
    var entriesByDate: [(date: String, entries: [TimeEntry])] {
        Dictionary(grouping: data.entries, by: { $0.date })
            .sorted { $0.key > $1.key }
            .map { (date: $0.key, entries: $0.value.sorted { $0.clockIn > $1.clockIn }) }
    }

    /// Check if there's an incomplete session from crash
    var hasIncompleteSession: Bool {
        data.currentSession != nil
    }

    private init(
        dataStore: DataStore,
        notificationManager: NotificationManager
    ) {
        self.dataStore = dataStore
        self.notificationManager = notificationManager
        self.reminderScheduler = ReminderScheduler(notificationManager: notificationManager)

        loadData()
        setupSleepWatcher()
        checkIncompleteSession()
    }

    private func setupSleepWatcher() {
        sleepWatcher = SleepWatcher(
            shouldStopOnSleep: { SettingsManager.shared.stopOnSleep },
            onSleep: { [weak self] in
                Task { @MainActor in
                    self?.clockOut()
                }
            }
        )
    }

    private func loadData() {
        do {
            data = try dataStore.load()
        } catch {
            lastError = error
            data = ClockletData()
        }
    }

    private func checkIncompleteSession() {
        guard data.currentSession != nil else { return }
        Task { @MainActor in
            await notificationManager.showIncompleteSessionNotification()
        }
    }

    func toggle() {
        if isTracking {
            clockOut()
        } else {
            clockIn()
        }
    }

    func clockIn() {
        // Request notification permission on first clock in
        Task {
            await notificationManager.requestPermissionIfNeeded()
        }

        data.currentSession = CurrentSession(clockIn: Date())
        save()
        reminderScheduler.start()

        if SettingsManager.shared.clockEventNotificationEnabled {
            Task {
                await notificationManager.sendClockInNotification()
            }
        }
    }

    func clockOut() {
        guard let session = data.currentSession else { return }

        do {
            let entry = try TimeEntry(clockIn: session.clockIn, clockOut: Date())
            data.entries.append(entry)
            data.currentSession = nil
            save()
            reminderScheduler.stop()

            if SettingsManager.shared.clockEventNotificationEnabled {
                Task {
                    await notificationManager.sendClockOutNotification(durationSeconds: entry.durationSeconds)
                }
            }
        } catch {
            lastError = error
        }
    }

    func updateEntry(_ entry: TimeEntry, clockIn: Date, clockOut: Date) {
        guard let index = data.entries.firstIndex(where: { $0.id == entry.id }) else { return }

        do {
            var updated = entry
            try updated.update(clockIn: clockIn, clockOut: clockOut)
            data.entries[index] = updated
            save()
        } catch {
            lastError = error
        }
    }

    func deleteEntry(_ entry: TimeEntry) {
        data.entries.removeAll { $0.id == entry.id }
        save()
    }

    /// Delete multiple entries at once
    func deleteEntries(_ entries: Set<TimeEntry.ID>) {
        data.entries.removeAll { entries.contains($0.id) }
        save()
    }

    func addEntry(clockIn: Date, clockOut: Date) {
        do {
            let entry = try TimeEntry(clockIn: clockIn, clockOut: clockOut)
            data.entries.append(entry)
            save()
        } catch {
            lastError = error
        }
    }

    /// Complete an incomplete session (crash recovery)
    func completeIncompleteSession(clockOut: Date) {
        guard let session = data.currentSession else { return }

        do {
            let entry = try TimeEntry(clockIn: session.clockIn, clockOut: clockOut)
            data.entries.append(entry)
            data.currentSession = nil
            save()
        } catch {
            lastError = error
        }
    }

    /// Discard an incomplete session
    func discardIncompleteSession() {
        data.currentSession = nil
        save()
    }

    private func save() {
        do {
            try dataStore.save(data)
            lastError = nil
        } catch {
            lastError = error
        }
    }
}
