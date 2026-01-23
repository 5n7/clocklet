//
//  NotificationManager.swift
//  Clocklet
//

import Foundation
import UserNotifications

@MainActor
final class NotificationManager {
    private let center = UNUserNotificationCenter.current()

    func requestPermissionIfNeeded() async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }

        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            // Permission denied or error - notifications will silently fail
        }
    }

    func sendReminderNotification() async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Clocklet"
        content.body = "Did you forget to Clock Out?"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        try? await center.add(request)
    }

    func sendClockInNotification() async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Clocklet"
        let timeString = DateFormatters.timeOnly.string(from: Date())
        content.body = "Clocked in at \(timeString)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        try? await center.add(request)
    }

    func sendClockOutNotification(durationSeconds: Int) async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Clocklet"
        content.body = "Clocked out. Duration: \(DurationFormatter.format(durationSeconds))"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        try? await center.add(request)
    }

    func showIncompleteSessionNotification() async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Clocklet"
        content.body = "Incomplete session found. Please set the Clock Out time."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "incomplete-session",
            content: content,
            trigger: nil
        )

        try? await center.add(request)
    }
}
