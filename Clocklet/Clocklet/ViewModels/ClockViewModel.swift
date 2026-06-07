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

  var isTracking: Bool {
    data.currentSession != nil
  }

  var currentSessionDuration: TimeInterval {
    guard let session = data.currentSession else { return 0 }
    return Date().timeIntervalSince(session.clockIn)
  }

  var todayDuration: TimeInterval { todayTotals.duration }
  var todayEarnings: Int { todayTotals.earnings }
  var thisMonthDuration: TimeInterval { thisMonthTotals.duration }
  var thisMonthEarnings: Int { thisMonthTotals.earnings }
  var lastMonthDuration: TimeInterval { lastMonthTotals.duration }
  var lastMonthEarnings: Int { lastMonthTotals.earnings }

  private var todayTotals: (duration: TimeInterval, earnings: Int) {
    let now = Date()
    let today = DateFormatters.dateOnly.string(from: now)
    var duration: TimeInterval = 0
    var earnings: Int = 0
    for entry in data.entries where entry.date == today {
      duration += TimeInterval(entry.durationSeconds)
      earnings += entry.earnings
    }
    if let session = data.currentSession,
      DateFormatters.dateOnly.string(from: session.clockIn) == today
    {
      let sessionDuration = now.timeIntervalSince(session.clockIn)
      duration += sessionDuration
      earnings += EarningsCalculator.calculate(
        hourlyRate: session.hourlyRate,
        durationSeconds: sessionDuration
      )
    }
    return (duration, earnings)
  }

  private var thisMonthTotals: (duration: TimeInterval, earnings: Int) {
    let now = Date()
    let calendar = Calendar.current
    var duration: TimeInterval = 0
    var earnings: Int = 0
    for entry in data.entries
    where calendar.isDate(entry.clockIn, equalTo: now, toGranularity: .month) {
      duration += TimeInterval(entry.durationSeconds)
      earnings += entry.earnings
    }
    if let session = data.currentSession,
      calendar.isDate(session.clockIn, equalTo: now, toGranularity: .month)
    {
      let sessionDuration = now.timeIntervalSince(session.clockIn)
      duration += sessionDuration
      earnings += EarningsCalculator.calculate(
        hourlyRate: session.hourlyRate,
        durationSeconds: sessionDuration
      )
    }
    return (duration, earnings)
  }

  private var lastMonthTotals: (duration: TimeInterval, earnings: Int) {
    let calendar = Calendar.current
    guard let lastMonth = calendar.date(byAdding: .month, value: -1, to: Date()) else {
      return (0, 0)
    }
    var duration: TimeInterval = 0
    var earnings: Int = 0
    for entry in data.entries
    where calendar.isDate(entry.clockIn, equalTo: lastMonth, toGranularity: .month) {
      duration += TimeInterval(entry.durationSeconds)
      earnings += entry.earnings
    }
    return (duration, earnings)
  }

  /// Entries grouped by date for history view
  var entriesByDate: [(date: String, entries: [TimeEntry])] {
    Dictionary(grouping: data.entries, by: { $0.date })
      .sorted { $0.key > $1.key }
      .map { (date: $0.key, entries: $0.value.sorted { $0.clockIn > $1.clockIn }) }
  }

  var oldestStatisticsMonth: Date? {
    let oldestEntry = data.entries.min(by: { $0.clockIn < $1.clockIn })?.clockIn
    let oldestSession = data.currentSession?.clockIn
    let oldestDate = [oldestEntry, oldestSession].compactMap { $0 }.min()
    guard let oldestDate else { return nil }
    return monthStart(containing: oldestDate)
  }

  /// Get monthly statistics for the specified number of months ending at the target month.
  func monthlyStatistics(months: Int = 12, endingAt endDate: Date = Date()) -> [MonthlyStatistics] {
    let calendar = Calendar.current
    let now = Date()
    guard let endMonth = monthStart(containing: endDate) else {
      return []
    }

    let totalsByMonth = totalsByMonth(now: now, calendar: calendar)

    var statistics: [MonthlyStatistics] = []
    for i in 0..<months {
      guard let date = calendar.date(byAdding: .month, value: -i, to: endMonth) else { continue }
      let components = calendar.dateComponents([.year, .month], from: date)
      guard let year = components.year, let month = components.month else { continue }
      let key = MonthlyStatistics.makeKey(year: year, month: month)
      let totals = totalsByMonth[key] ?? (seconds: 0, earnings: 0)
      statistics.append(
        MonthlyStatistics(
          year: year,
          month: month,
          totalSeconds: totals.seconds,
          totalEarnings: totals.earnings
        ))
    }

    return statistics.reversed()
  }

  /// Get daily statistics for the specified month.
  func dailyStatistics(forMonthContaining date: Date = Date()) -> [DailyStatistics] {
    let calendar = Calendar.current
    let now = Date()
    guard let targetMonth = monthStart(containing: date) else {
      return []
    }

    let targetComponents = calendar.dateComponents([.year, .month], from: targetMonth)
    guard let year = targetComponents.year, let month = targetComponents.month else {
      return []
    }

    guard let range = calendar.range(of: .day, in: .month, for: targetMonth) else {
      return []
    }

    var totalsByDay: [String: (seconds: Int, earnings: Int)] = [:]

    for entry in data.entries {
      let components = calendar.dateComponents([.year, .month, .day], from: entry.clockIn)
      guard let entryYear = components.year, let entryMonth = components.month,
        let entryDay = components.day,
        entryYear == year, entryMonth == month
      else { continue }
      let key = DailyStatistics.makeKey(year: entryYear, month: entryMonth, day: entryDay)
      totalsByDay[key, default: (seconds: 0, earnings: 0)].seconds += entry.durationSeconds
      totalsByDay[key, default: (seconds: 0, earnings: 0)].earnings += entry.earnings
    }

    if let session = data.currentSession {
      let sessionComponents = calendar.dateComponents([.year, .month, .day], from: session.clockIn)
      if let sessionYear = sessionComponents.year, let sessionMonth = sessionComponents.month,
        let sessionDay = sessionComponents.day,
        sessionYear == year, sessionMonth == month
      {
        let key = DailyStatistics.makeKey(year: sessionYear, month: sessionMonth, day: sessionDay)
        let duration = statisticsDuration(for: session, now: now, calendar: calendar)
        totalsByDay[key, default: (seconds: 0, earnings: 0)].seconds += duration
        totalsByDay[key, default: (seconds: 0, earnings: 0)].earnings +=
          EarningsCalculator.calculate(
            hourlyRate: session.hourlyRate,
            durationSeconds: TimeInterval(duration)
          )
      }
    }

    let isCurrentMonth = calendar.isDate(targetMonth, equalTo: now, toGranularity: .month)
    let lastDay = isCurrentMonth ? calendar.component(.day, from: now) : (range.last ?? 0)

    var statistics: [DailyStatistics] = []
    for day in range {
      if day > lastDay { break }
      let key = DailyStatistics.makeKey(year: year, month: month, day: day)
      let totals = totalsByDay[key] ?? (seconds: 0, earnings: 0)
      statistics.append(
        DailyStatistics(
          year: year,
          month: month,
          day: day,
          totalSeconds: totals.seconds,
          totalEarnings: totals.earnings
        ))
    }

    return statistics
  }

  private func totalsByMonth(now: Date, calendar: Calendar) -> [String: (seconds: Int, earnings: Int)] {
    var totalsByMonth: [String: (seconds: Int, earnings: Int)] = [:]

    for entry in data.entries {
      let components = calendar.dateComponents([.year, .month], from: entry.clockIn)
      guard let year = components.year, let month = components.month else { continue }
      let key = MonthlyStatistics.makeKey(year: year, month: month)
      totalsByMonth[key, default: (seconds: 0, earnings: 0)].seconds += entry.durationSeconds
      totalsByMonth[key, default: (seconds: 0, earnings: 0)].earnings += entry.earnings
    }

    if let session = data.currentSession {
      let sessionComponents = calendar.dateComponents([.year, .month], from: session.clockIn)
      if let sessionYear = sessionComponents.year, let sessionMonth = sessionComponents.month {
        let key = MonthlyStatistics.makeKey(year: sessionYear, month: sessionMonth)
        let duration = statisticsDuration(for: session, now: now, calendar: calendar)
        totalsByMonth[key, default: (seconds: 0, earnings: 0)].seconds += duration
        totalsByMonth[key, default: (seconds: 0, earnings: 0)].earnings +=
          EarningsCalculator.calculate(
            hourlyRate: session.hourlyRate,
            durationSeconds: TimeInterval(duration)
          )
      }
    }

    return totalsByMonth
  }

  private func statisticsDuration(
    for session: CurrentSession,
    now: Date,
    calendar: Calendar
  ) -> Int {
    guard let sessionMonthStart = monthStart(containing: session.clockIn),
      let nextMonthStart = calendar.date(byAdding: .month, value: 1, to: sessionMonthStart)
    else {
      return Int(now.timeIntervalSince(session.clockIn))
    }

    let effectiveEnd = min(now, nextMonthStart)
    return max(Int(effectiveEnd.timeIntervalSince(session.clockIn)), 0)
  }

  private func monthStart(containing date: Date) -> Date? {
    let calendar = Calendar.current
    let components = calendar.dateComponents([.year, .month], from: date)
    return calendar.date(from: components)
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

    data.currentSession = CurrentSession(
      clockIn: Date(),
      jobName: SettingsManager.shared.currentJobName,
      hourlyRate: SettingsManager.shared.hourlyRate
    )
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
      let entry = try TimeEntry(
        clockIn: session.clockIn,
        clockOut: Date(),
        jobName: session.jobName,
        hourlyRate: session.hourlyRate
      )
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

  func addEntry(clockIn: Date, clockOut: Date, jobName: String, hourlyRate: Int) {
    do {
      let entry = try TimeEntry(
        clockIn: clockIn,
        clockOut: clockOut,
        jobName: jobName,
        hourlyRate: hourlyRate
      )
      data.entries.append(entry)
      save()
    } catch {
      lastError = error
    }
  }

  func updateEntry(_ entry: TimeEntry, clockIn: Date, clockOut: Date, jobName: String, hourlyRate: Int) {
    guard let index = data.entries.firstIndex(where: { $0.id == entry.id }) else { return }

    do {
      var updated = entry
      try updated.update(clockIn: clockIn, clockOut: clockOut, jobName: jobName, hourlyRate: hourlyRate)
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

  /// Complete an incomplete session (crash recovery)
  func completeIncompleteSession(clockOut: Date) {
    guard let session = data.currentSession else { return }

    do {
      let entry = try TimeEntry(
        clockIn: session.clockIn,
        clockOut: clockOut,
        jobName: session.jobName,
        hourlyRate: session.hourlyRate
      )
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

  private func save() {
    do {
      try dataStore.save(data)
      lastError = nil
    } catch {
      lastError = error
    }
  }
}
