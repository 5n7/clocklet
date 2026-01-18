//
//  ReminderScheduler.swift
//  Clocklet
//

import Foundation

@MainActor
final class ReminderScheduler {
    private var timer: Timer?
    private let notificationManager: NotificationManager

    init(notificationManager: NotificationManager) {
        self.notificationManager = notificationManager
    }

    func start() {
        guard SettingsManager.shared.reminderEnabled else { return }

        let threshold = SettingsManager.shared.reminderThresholdMinutes
        scheduleNotification(after: TimeInterval(threshold * 60))
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func scheduleNotification(after interval: TimeInterval) {
        // Use RunLoop.Mode.common to ensure timer fires even when menu is open
        let timer = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleTimerFired()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func handleTimerFired() {
        Task {
            await notificationManager.sendReminderNotification()
        }
        scheduleRepeatIfNeeded()
    }

    private func scheduleRepeatIfNeeded() {
        guard let repeatMinutes = SettingsManager.shared.reminderRepeatMinutes else { return }
        scheduleNotification(after: TimeInterval(repeatMinutes * 60))
    }
}
