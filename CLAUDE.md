# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Clocklet is a macOS menu bar time-tracking app. Users clock in/out with one click or keyboard shortcut, view daily/monthly summaries, and receive reminders for forgotten clock-outs.

- **PRD**: `docs/prd.md`
- **Technical Design**: `docs/technical-design.md`

## Tech Stack

- **Language**: Swift
- **UI**: SwiftUI + AppKit (NSStatusItem for menu bar)
- **Architecture**: MVVM with @Observable
- **Data**: JSON file (`~/Library/Application Support/Clocklet/data.json`)
- **Settings**: UserDefaults
- **Minimum OS**: macOS 15.0 (Tahoe)

## Dependencies (SPM)

- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) - Global hotkey with recorder UI
- [LaunchAtLogin](https://github.com/sindresorhus/LaunchAtLogin) - Login item management

## Project Structure

```
Clocklet/
├── Models/          # TimeEntry, ClockletData, CurrentSession
├── ViewModels/      # ClockViewModel, HistoryViewModel
├── Views/           # MenuBarView, HistoryView, SettingsView, EditEntryView
├── Services/        # DataStore, SettingsManager, ReminderManager, SleepWatcher
└── Utilities/       # DateFormatters, DurationFormatter
```

## Commands

```bash
# Build
xcodebuild -scheme Clocklet -configuration Debug build

# Test
xcodebuild -scheme Clocklet test

# Format docs
pnpm format
```

## Key Implementation Notes

- Menu bar app uses `MenuBarExtra` (SwiftUI)
- JSON saved atomically (write to temp, then rename) for crash safety
- `currentSession` persisted immediately on clock-in for crash recovery
- Sleep detection via `NSWorkspace.willSleepNotification`
- Reminder uses `Timer` + `UNUserNotificationCenter`
