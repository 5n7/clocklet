# Clocklet - Product Requirements Document

## Overview

Clocklet is a time-tracking application that resides in the Mac status bar. It enables freelancers and self-employed individuals to easily record and manage their work hours for side jobs.

## Background and Objectives

### Background

- Accurate time tracking is essential for self-employed individuals managing side work
- Existing time-tracking tools are often feature-heavy and overkill for simple use cases
- A lightweight, Mac-native tool is needed

### Objectives

- Enable one-click or shortcut-based work time recording (start/stop)
- Provide easy access to daily and monthly work hour summaries
- Prevent forgotten clock-outs through reminder notifications

## Target Users

- Self-employed individuals with side jobs
- Freelancers
- Anyone who needs to track work hours

## Functional Requirements

### 1. Status Bar Integration

| Item          | Details                                                     |
| ------------- | ----------------------------------------------------------- |
| Location      | Mac status bar (menu bar)                                   |
| Icon          | Clock icon (visually distinguishable between In/Out states) |
| State Display | Current state (In/Out) identifiable by icon appearance      |

### 2. Clock In / Clock Out Feature

| Item             | Details                                         |
| ---------------- | ----------------------------------------------- |
| Clock In         | Records work start time                         |
| Clock Out        | Records work end time, calculates work duration |
| Operation        | Menu click or global shortcut key               |
| State Transition | Out → In → Out → In → Out ... (alternating)     |

#### State Transition Diagram

```
[Out State] ---(Clock In)---> [In State] ---(Clock Out)---> [Out State]
```

### 3. Shortcut Key Feature

| Item          | Details                                                                                                 |
| ------------- | ------------------------------------------------------------------------------------------------------- |
| Configurable  | User can set any key combination                                                                        |
| Reserved Keys | System shortcuts (Cmd+Q, Cmd+W, Cmd+H, Cmd+M, Cmd+Tab, Cmd+Space, etc.) are rejected with error message |
| Default       | Not set (user registers via settings screen)                                                            |
| Behavior      | Executes Clock In or Clock Out based on current state                                                   |

### 4. Log Management Feature

| Item              | Details                                                     |
| ----------------- | ----------------------------------------------------------- |
| Recorded Data     | Date, Clock In time, Clock Out time, work duration          |
| Storage Format    | JSON file (human-readable, easy to debug/edit manually)     |
| Storage Location  | `~/Library/Application Support/Clocklet/data.json`          |
| Data Retention    | Persistent storage                                          |
| Timezone          | Uses system timezone (OS setting)                           |
| Midnight Crossing | Sessions spanning midnight are counted under the start date |

#### Log Data Structure

**When clocked in (tracking):**

```json
{
  "version": 1,
  "currentSession": {
    "clockIn": "2026-01-18T14:00:00+09:00"
  },
  "entries": [...]
}
```

**When clocked out (idle):**

```json
{
  "version": 1,
  "currentSession": null,
  "entries": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "date": "2026-01-18",
      "clockIn": "2026-01-18T09:00:00+09:00",
      "clockOut": "2026-01-18T12:30:00+09:00",
      "durationSeconds": 12600,
      "createdAt": "2026-01-18T12:30:00+09:00",
      "modifiedAt": null
    }
  ]
}
```

**Notes:**

- `version`: Data format version for future migrations
- `currentSession`: Tracks in-progress session (null when clocked out)
- All timestamps use ISO 8601 format with timezone offset
- `durationSeconds`: Calculated from timestamps
- Zero-duration sessions are not expected to occur (UI prevents immediate clock-out)

### 5. Aggregation and Display Feature

| Item            | Details                                                         |
| --------------- | --------------------------------------------------------------- |
| Daily Summary   | Displays total work hours for the day                           |
| Monthly Summary | Displays total work hours for the current month                 |
| History View    | Lists past logs in reverse chronological order, grouped by date |
| Access Point    | Accessible from status bar menu                                 |

#### Display Example

```
Today: 3h 30m
This Month: 42h 15m
---
View History →
```

### 6. Reminder Feature

| Item                 | Details                                                                                                          |
| -------------------- | ---------------------------------------------------------------------------------------------------------------- |
| Trigger              | Clock In state continues beyond threshold                                                                        |
| Default Threshold    | 60 minutes                                                                                                       |
| Threshold Setting    | User selects from preset options: 15, 30, 45, 60, 90, 120, 180, 240, 300, 360, 480 minutes                       |
| Notification Method  | macOS standard notification                                                                                      |
| Notification Content | "Did you forget to Clock Out?"                                                                                   |
| Repeat               | Configurable (off / 15 / 30 / 60 minutes interval)                                                               |
| Repeat Behavior      | Timer resets after each notification (e.g., 60min threshold + 15min repeat = notify at 60min, 75min, 90min, ...) |

### 7. Data Editing Feature

| Item            | Details                                                    |
| --------------- | ---------------------------------------------------------- |
| Edit Target     | Past log entries                                           |
| Editable Fields | Clock In time, Clock Out time                              |
| Add             | Manually add new entries                                   |
| Delete          | Delete existing entries (single or bulk)                   |
| Bulk Delete     | Select multiple entries and delete at once                 |
| Validation      | Clock Out must be after Clock In; future dates not allowed |
| UI              | Dedicated editing window                                   |

#### Bulk Delete Feature

| Item             | Details                                                            |
| ---------------- | ------------------------------------------------------------------ |
| Checkbox Display | Always visible on the left of each entry                           |
| Selection        | Click checkbox to select/deselect; click entry content to edit     |
| Visual Indicator | Filled checkmark when selected, empty circle when not selected     |
| Toolbar (none)   | Shows "Select All" button                                          |
| Toolbar (some)   | Shows "Deselect All" and "Delete (N)" buttons                      |
| Delete Action    | "Delete (N)" button appears when entries are selected              |
| Confirmation     | Dialog: "Delete N entries? This cannot be undone." [Cancel/Delete] |
| State Reset      | Selections reset when closing window                               |

**Keyboard Shortcuts:**

| Shortcut | Action                |
| -------- | --------------------- |
| Cmd+A    | Select all entries    |
| Delete   | Trigger delete dialog |
| Escape   | Clear all selections  |

### 8. Settings Feature

| Setting Item             | Details                                    | Default Value |
| ------------------------ | ------------------------------------------ | ------------- |
| Shortcut Key             | Global hotkey configuration                | Not set       |
| Reminder Threshold       | Time until Clock Out reminder              | 60 minutes    |
| Reminder Enable/Disable  | Toggle reminder feature                    | Enabled       |
| Reminder Repeat Interval | Interval for repeated reminders            | Off           |
| Launch at Login          | Auto-start on Mac boot                     | Disabled      |
| Stop on Sleep            | Automatically clock out when system sleeps | Enabled       |

## System Behavior

### Sleep/Wake Handling

| Behavior     | Details                                                                        |
| ------------ | ------------------------------------------------------------------------------ |
| Default      | Automatically clock out when system enters sleep mode                          |
| Configurable | User can disable auto clock-out on sleep                                       |
| Wake Resume  | If auto clock-out is disabled, tracking continues with elapsed wall-clock time |

### Crash Recovery

| Behavior       | Details                                                                                                     |
| -------------- | ----------------------------------------------------------------------------------------------------------- |
| On Clock In    | `currentSession` is immediately saved to disk                                                               |
| On Clock Out   | Entry is moved to `entries` array, `currentSession` is cleared                                              |
| On Crash       | `currentSession` remains in data file                                                                       |
| On Next Launch | If `currentSession` exists, show notification prompting user to manually set Clock Out time via edit screen |
| Rationale      | Simple implementation; crash is rare; user has full control via editing                                     |

### First Launch

| Behavior      | Details                                                     |
| ------------- | ----------------------------------------------------------- |
| Initial State | App starts in "Out" state                                   |
| Onboarding    | No onboarding flow; minimal setup required                  |
| Permissions   | Notification permission requested on first reminder trigger |

## Non-Functional Requirements

### Performance

- App memory usage: Under 50MB
- Startup time: Within 2 seconds
- Background CPU usage: < 1% when idle

### Reliability

- Data persistence (logs retained after app termination)
- Immediate save on Clock In and Clock Out operations
- Atomic file writes to prevent data corruption

### Usability

- Intuitive operation (one-click Clock In/Out)
- Simple UI
- Compliance with macOS Human Interface Guidelines

### Compatibility

- **Minimum OS**: macOS 26.2 or later
- Support Apple Silicon (M1/M2/M3/M4) and Intel Mac

## Technical Stack

| Category      | Technology                   |
| ------------- | ---------------------------- |
| Language      | Swift                        |
| Framework     | SwiftUI / AppKit             |
| Data Storage  | JSON file (Codable)          |
| Notifications | UserNotifications framework  |
| Shortcuts     | HotKey library or Carbon API |

**Design Rationale:**

- JSON chosen over SwiftData for simplicity, human-readability, and ease of debugging
- Single-user app with small data volume; no need for database complexity
- Engineers can manually inspect/edit data file if needed

## UI/UX Design

### Status Bar Menu Structure

```
┌─────────────────────────────┐
│ ● Clock Out                │  ← When currently In state (green indicator)
├─────────────────────────────┤
│ Today: 2h 30m              │
│ This Month: 38h 45m        │
│ Started: 14:00             │  ← Shows current session start time
├─────────────────────────────┤
│ History                  → │
│ Settings                 → │
├─────────────────────────────┤
│ Quit                       │
└─────────────────────────────┘
```

```
┌─────────────────────────────┐
│ ○ Clock In                 │  ← When currently Out state (gray indicator)
├─────────────────────────────┤
│ Today: 2h 30m              │
│ This Month: 38h 45m        │
├─────────────────────────────┤
│ History                  → │
│ Settings                 → │
├─────────────────────────────┤
│ Quit                       │
└─────────────────────────────┘
```

### Icon States

| State               | Icon Display     |
| ------------------- | ---------------- |
| Clock Out (Idle)    | Gray clock icon  |
| Clock In (Tracking) | Green clock icon |

## Future Extensions (Out of Scope)

The following are out of scope for the initial version but may be considered in the future:

- Multiple project support
- CSV/Excel export feature
- iCloud sync
- Notes/tags feature
- Report generation feature

## Success Criteria

- Clock In/Out can be completed with one click
- Monthly work hours can be checked instantly
- Reminders prevent forgotten Clock Outs
- System sleep properly handles active sessions
- Crash recovery prompts user to complete incomplete sessions

## Schedule (Milestones)

| Phase   | Content                                                    |
| ------- | ---------------------------------------------------------- |
| Phase 1 | Core features (Clock In/Out, log storage, summary display) |
| Phase 2 | Shortcut keys, reminder feature                            |
| Phase 3 | Data editing feature, settings screen                      |
| Phase 4 | UI/UX improvements, stabilization                          |

---

_Document Version: 1.4_
_Last Updated: 2026-01-18_
