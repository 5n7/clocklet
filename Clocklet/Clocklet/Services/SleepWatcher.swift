//
//  SleepWatcher.swift
//  Clocklet
//

import AppKit
import Foundation

final class SleepWatcher {
    private let shouldStopOnSleep: () -> Bool
    private let onSleep: () -> Void

    init(shouldStopOnSleep: @escaping () -> Bool, onSleep: @escaping () -> Void) {
        self.shouldStopOnSleep = shouldStopOnSleep
        self.onSleep = onSleep

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    @objc private func handleSleep() {
        if shouldStopOnSleep() {
            onSleep()
        }
    }
}
