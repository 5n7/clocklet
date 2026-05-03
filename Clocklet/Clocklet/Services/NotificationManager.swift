//
//  NotificationManager.swift
//  Clocklet
//

import AppKit
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
    applyNotificationSound(to: content)

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
    applyNotificationSound(to: content)

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
    applyNotificationSound(to: content)

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
    applyNotificationSound(to: content)

    let request = UNNotificationRequest(
      identifier: "incomplete-session",
      content: content,
      trigger: nil
    )

    try? await center.add(request)
  }

  private func applyNotificationSound(to content: UNMutableNotificationContent) {
    let sound = SettingsManager.shared.notificationSound

    switch sound {
    case .default:
      content.sound = .default
    case .none:
      content.sound = nil
    default:
      content.sound = nil
      NSSound(named: NSSound.Name(sound.rawValue))?.play()
    }
  }
}
