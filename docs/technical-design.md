# Clocklet - Technical Design Document

## Overview

This document defines the technical architecture and implementation details for Clocklet, a macOS menu bar time-tracking application.

## Technology Decisions

| Category           | Decision                            | Rationale                                     |
| ------------------ | ----------------------------------- | --------------------------------------------- |
| Language           | Swift                               | Native macOS, lightweight, full API access    |
| UI Framework       | SwiftUI + AppKit                    | SwiftUI for views, AppKit for NSStatusItem    |
| Architecture       | MVVM                                | Clean separation, testable, SwiftUI-friendly  |
| State Management   | @Observable (Observation framework) | Modern, performant, macOS 15+ supported       |
| Dependency Manager | Swift Package Manager               | Xcode-integrated, simple                      |
| Data Persistence   | JSON + Codable                      | Human-readable, debuggable, manually editable |
| Settings Storage   | UserDefaults                        | Apple standard for app preferences            |
| Global Shortcuts   | KeyboardShortcuts                   | Built-in recorder UI, SwiftUI support         |
| Minimum OS         | macOS 26.2                          | Enables latest Swift features                 |

## Dependencies

| Package           | Purpose                                                                | URL                                                  |
| ----------------- | ---------------------------------------------------------------------- | ---------------------------------------------------- |
| KeyboardShortcuts | Global hotkey with recorder UI (includes reserved shortcut validation) | https://github.com/sindresorhus/KeyboardShortcuts    |
| LaunchAtLogin     | Login item management                                                  | https://github.com/sindresorhus/LaunchAtLogin-Modern |

**Note:** KeyboardShortcuts library internally validates and rejects system-reserved shortcuts (Cmd+Q, Cmd+W, Cmd+H, Cmd+M, Cmd+Tab, Cmd+Space, etc.) with a shake animation feedback.

## Project Structure

```
Clocklet/
├── Clocklet.xcodeproj
├── Clocklet/
│   ├── ClockletApp.swift              # @main, app lifecycle
│   │
│   ├── Models/
│   │   ├── TimeEntry.swift            # Single work session
│   │   ├── ClockletData.swift         # All entries + current session
│   │   └── CurrentSession.swift       # In-progress tracking
│   │
│   ├── ViewModels/
│   │   └── ClockViewModel.swift       # Main clock state, clock in/out logic, history
│   │
│   ├── Views/
│   │   ├── MenuBarView.swift          # Status bar menu content
│   │   ├── HistoryView.swift          # Past entries list (includes HistoryRowView)
│   │   ├── EditEntryView.swift        # Add/edit entry sheet
│   │   └── SettingsView.swift         # Preferences window
│   │
│   ├── Services/
│   │   ├── DataStore.swift            # JSON read/write, atomic saves
│   │   ├── SettingsManager.swift      # UserDefaults wrapper
│   │   ├── NotificationManager.swift  # Permission + notifications
│   │   ├── ReminderScheduler.swift    # Timer scheduling
│   │   └── SleepWatcher.swift         # NSWorkspace sleep/wake observer
│   │
│   ├── Utilities/
│   │   ├── DateFormatters.swift       # ISO8601, display formatters
│   │   └── DurationFormatter.swift    # "2h 30m" formatting
│   │
│   └── Resources/
│       ├── Assets.xcassets/
│       │   └── AppIcon.appiconset/
│       └── Localizable.strings        # (future: localization)
│
│   # Note: Menu bar icons use SF Symbols (clock, clock.fill) instead of custom assets
│
├── ClockletTests/
│   ├── TimeEntryTests.swift
│   ├── ClockViewModelTests.swift
│   ├── DataStoreTests.swift
│   └── DurationFormatterTests.swift
│
└── Package.swift                      # SPM dependencies (or via Xcode)
```

## Data Models

### ClockletData (JSON file)

```swift
struct ClockletData: Codable {
    var version: Int = 1
    var currentSession: CurrentSession?
    var entries: [TimeEntry] = []
}
```

**File location:** `~/Library/Application Support/Clocklet/data.json`

### CurrentSession

```swift
struct CurrentSession: Codable {
    let clockIn: Date
}
```

### TimeEntry

```swift
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
```

**Design note:** `date` and `durationSeconds` are computed properties to prevent data inconsistency when entries are edited.

### Settings (UserDefaults)

```swift
enum SettingsKey: String {
    case reminderThresholdMinutes       // Int, default: 60
    case reminderEnabled                // Bool, default: true
    case reminderRepeatMinutes          // Int?, default: nil (off)
    case stopOnSleep                    // Bool, default: true
    // launchAtLogin handled by LaunchAtLogin package
    // shortcut handled by KeyboardShortcuts package
}
```

## Component Design

### ClockletApp (Entry Point)

```swift
@main
struct ClockletApp: App {
    // Singleton pattern: ClockViewModel.shared used for global shortcut access
    private var viewModel: ClockViewModel { ClockViewModel.shared }

    init() {
        // Register global keyboard shortcut at app launch
        KeyboardShortcuts.onKeyUp(for: .toggleClock) {
            Task { @MainActor in
                ClockViewModel.shared.toggle()
            }
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(viewModel: viewModel)
        } label: {
            // Uses SF Symbols instead of custom assets
            Image(systemName: viewModel.isTracking ? "clock.fill" : "clock")
                .symbolRenderingMode(.hierarchical)
                .foregroundColor(viewModel.isTracking ? .green : .primary)
        }
        .menuBarExtraStyle(.window)  // Window-style popover menu

        Settings {
            SettingsView()
        }

        Window("History", id: "history") {
            HistoryView(viewModel: viewModel)
        }
        .defaultSize(width: 500, height: 400)
    }
}
```

**Implementation notes:**

- Uses singleton pattern (`ClockViewModel.shared`) to allow global keyboard shortcuts to access the view model
- Uses `.menuBarExtraStyle(.window)` for a window-style popover menu
- Uses SF Symbols (`clock`, `clock.fill`) for menu bar icons instead of custom assets

### ClockViewModel

```swift
@MainActor
@Observable
final class ClockViewModel {
    // Singleton for global keyboard shortcut access
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

    /// Current session elapsed time (for live display)
    var currentSessionDuration: TimeInterval {
        guard let session = data.currentSession else { return 0 }
        return Date().timeIntervalSince(session.clockIn)
    }

    var todayDuration: TimeInterval {
        let now = Date()  // Capture once to prevent data race
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
        let now = Date()  // Capture once to prevent data race
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

    /// Entries grouped by date for history view
    var entriesByDate: [(date: String, entries: [TimeEntry])] {
        Dictionary(grouping: data.entries, by: { $0.date })
            .sorted { $0.key > $1.key }
            .map { (date: $0.key, entries: $0.value.sorted { $0.clockIn > $1.clockIn }) }
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
        notificationManager.showIncompleteSessionNotification()
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
    }

    func clockOut() {
        guard let session = data.currentSession else { return }

        do {
            let entry = try TimeEntry(clockIn: session.clockIn, clockOut: Date())
            data.entries.append(entry)
            data.currentSession = nil
            save()
            reminderScheduler.stop()
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
            // TODO: Show error to user via notification or alert
        }
    }
}
```

### HistoryView

The HistoryView displays past entries with always-visible checkboxes for bulk selection and deletion.

**State Management:**

```swift
struct HistoryView: View {
    @Bindable var viewModel: ClockViewModel
    @State private var selectedEntry: TimeEntry?      // For editing
    @State private var isAddingEntry = false
    @State private var selectedEntries: Set<TimeEntry.ID> = []  // Selected for deletion
    @State private var showDeleteConfirmation = false

    private func toggleSelection(_ id: TimeEntry.ID) {
        if selectedEntries.contains(id) {
            selectedEntries.remove(id)
        } else {
            selectedEntries.insert(id)
        }
    }

    private func selectAll() {
        selectedEntries = Set(viewModel.data.entries.map(\.id))
    }
}
```

**Row Layout:**

Each row displays a checkbox on the left side, always visible:

```swift
HStack(spacing: 12) {
    // Checkbox - clicking toggles selection
    Image(systemName: selectedEntries.contains(entry.id) ? "checkmark.circle.fill" : "circle")
        .onTapGesture { toggleSelection(entry.id) }

    // Entry content - clicking opens edit
    HistoryRowView(entry: entry)
        .onTapGesture { selectedEntry = entry }
}
```

**Toolbar Behavior:**

| Selection State | Toolbar Contents                |
| --------------- | ------------------------------- |
| None selected   | [Select All] [+]                |
| Some selected   | [Deselect All] [Delete (N)] [+] |

**Visual Indicators:**

- Selected: `checkmark.circle.fill` with accent color
- Not selected: `circle` with secondary color

**Keyboard Shortcuts:**

```swift
.keyboardShortcut("a", modifiers: .command)  // Select all (on Select All button)
.onKeyPress(.delete) { ... }                  // Trigger delete confirmation
.onKeyPress(.escape) { ... }                  // Clear all selections
```

**UI Flow:**

```
List with checkboxes always visible
    ├── Click checkbox → Toggle selection for that entry
    ├── Click entry content → Open edit sheet
    ├── "Select All" → Select all entries
    ├── "Deselect All" → Clear all selections
    ├── "Delete (N)" → Show confirmation dialog
    │       ├── Confirm → viewModel.deleteEntries(selectedEntries), clear selections
    │       └── Cancel → Keep selections
    └── Escape key → Clear all selections
```

**State Reset:** Selections are view-local `@State` and automatically reset when the window closes.

### DataStore

```swift
enum DataStoreError: LocalizedError {
    case encodingFailed
    case writeFailed(Error)
    case decodingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode data"
        case .writeFailed(let error):
            return "Failed to write data: \(error.localizedDescription)"
        case .decodingFailed(let error):
            return "Failed to decode data: \(error.localizedDescription)"
        }
    }
}

@MainActor
final class DataStore {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Could not locate Application Support directory")
        }
        let clockletDir = appSupport.appendingPathComponent("Clocklet", isDirectory: true)
        try? FileManager.default.createDirectory(at: clockletDir, withIntermediateDirectories: true)
        self.fileURL = clockletDir.appendingPathComponent("data.json")

        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func load() throws -> ClockletData {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return ClockletData()
        }

        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode(ClockletData.self, from: data)
        } catch {
            throw DataStoreError.decodingFailed(error)
        }
    }

    func save(_ data: ClockletData) throws {
        guard let jsonData = try? encoder.encode(data) else {
            throw DataStoreError.encodingFailed
        }

        do {
            // Atomic write: writes to temp file then renames
            try jsonData.write(to: fileURL, options: .atomic)
        } catch {
            throw DataStoreError.writeFailed(error)
        }
    }
}
```

### NotificationManager

```swift
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
```

### ReminderScheduler

```swift
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

    @MainActor
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
```

### SleepWatcher

```swift
import AppKit

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
```

### SettingsManager

```swift
import Foundation

final class SettingsManager {
    static let shared = SettingsManager()

    private let defaults = UserDefaults.standard

    private init() {}

    var reminderThresholdMinutes: Int {
        get { defaults.object(forKey: SettingsKey.reminderThresholdMinutes.rawValue) as? Int ?? 60 }
        set { defaults.set(newValue, forKey: SettingsKey.reminderThresholdMinutes.rawValue) }
    }

    var reminderEnabled: Bool {
        get { defaults.object(forKey: SettingsKey.reminderEnabled.rawValue) as? Bool ?? true }
        set { defaults.set(newValue, forKey: SettingsKey.reminderEnabled.rawValue) }
    }

    var reminderRepeatMinutes: Int? {
        get { defaults.object(forKey: SettingsKey.reminderRepeatMinutes.rawValue) as? Int }
        set { defaults.set(newValue, forKey: SettingsKey.reminderRepeatMinutes.rawValue) }
    }

    var stopOnSleep: Bool {
        get { defaults.object(forKey: SettingsKey.stopOnSleep.rawValue) as? Bool ?? true }
        set { defaults.set(newValue, forKey: SettingsKey.stopOnSleep.rawValue) }
    }
}
```

## Key Flows

### Clock In Flow

```
User clicks "Clock In" or presses shortcut
    ↓
ClockViewModel.clockIn()
    ├── Request notification permission (async, if not already requested)
    ├── Create CurrentSession with current timestamp
    ├── Save to JSON immediately (crash recovery)
    ├── Start ReminderScheduler timer
    └── Update UI (icon turns green)
```

### Clock Out Flow

```
User clicks "Clock Out" or presses shortcut
    ↓
ClockViewModel.clockOut()
    ├── Validate clockOut > clockIn
    ├── Create TimeEntry from CurrentSession
    ├── Append to entries array
    ├── Clear currentSession
    ├── Save to JSON
    ├── Stop ReminderScheduler
    └── Update UI (icon turns gray)
```

### App Launch Flow

```
App starts
    ↓
Load data.json
    ↓
Check if currentSession exists?
    ├── Yes → Show notification: "Incomplete session found. Please set Clock Out time."
    │         User can complete or discard via edit screen
    └── No  → Normal start in "Out" state
```

### System Sleep Flow

```
NSWorkspace.willSleepNotification received
    ↓
Check shouldStopOnSleep()?
    ├── true  → ClockViewModel.clockOut()
    └── false → Do nothing (tracking continues)
```

## Error Handling Strategy

| Error Type                              | Handling                   | User Feedback                   |
| --------------------------------------- | -------------------------- | ------------------------------- |
| JSON decode failure                     | Use empty ClockletData     | Log error, app continues        |
| JSON save failure                       | Store error in `lastError` | Show alert/notification         |
| Invalid TimeEntry (clockOut <= clockIn) | Throw error, don't save    | Show error message in UI        |
| Notification permission denied          | Silently fail              | None (notifications don't work) |

## Testing Strategy

| Layer      | Test Type         | Coverage                                   |
| ---------- | ----------------- | ------------------------------------------ |
| Models     | Unit tests        | TimeEntry validation, computed properties  |
| ViewModels | Unit tests        | Clock in/out logic, aggregation, editing   |
| DataStore  | Integration tests | JSON read/write, atomic saves, error cases |
| Services   | Unit tests        | ReminderScheduler timing                   |

## Build & Run

```bash
# Open in Xcode
open Clocklet.xcodeproj

# Build
xcodebuild -scheme Clocklet -configuration Debug build

# Run tests
xcodebuild -scheme Clocklet test

# Archive for release
xcodebuild -scheme Clocklet -configuration Release archive
```

## Security Considerations

- No network access required
- Data stored locally only
- No sensitive data (just timestamps)
- App Sandbox compatible

---

_Document Version: 1.3_
_Last Updated: 2026-01-18_
