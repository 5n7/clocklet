# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Clocklet is a macOS menu bar time-tracking app. Users clock in/out with one click or keyboard shortcut, view daily/monthly summaries, and receive reminders for forgotten clock-outs.

- **PRD**: `docs/prd.md`
- **Technical Design**: `docs/technical-design.md`

## Tech Stack

- **Language**: Swift
- **UI**: SwiftUI + AppKit (MenuBarExtra for menu bar)
- **Architecture**: MVVM with @Observable
- **Data**: JSON file (`~/Library/Application Support/Clocklet/data.json`)
- **Settings**: UserDefaults
- **Minimum OS**: macOS 15.0 (Sequoia)

## Dependencies (SPM)

- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) - Global hotkey with recorder UI
- [LaunchAtLogin](https://github.com/sindresorhus/LaunchAtLogin-Modern) - Login item management

## Project Structure

```
Clocklet/
├── Models/          # TimeEntry, ClockletData, CurrentSession
├── ViewModels/      # ClockViewModel
├── Views/           # MenuBarView, HistoryView, SettingsView, EditEntryView
├── Services/        # DataStore, SettingsManager, NotificationManager, ReminderScheduler, SleepWatcher
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

- Menu bar app uses `MenuBarExtra` with `.menuBarExtraStyle(.window)`
- JSON saved atomically (write to temp, then rename) for crash safety
- `currentSession` persisted immediately on clock-in for crash recovery
- Sleep detection via `NSWorkspace.willSleepNotification`
- Reminder uses `Timer` + `UNUserNotificationCenter`
- All UI classes use `@MainActor` for thread safety

---

## Development Workflow

This project follows a documentation-first approach with reviewer agents for quality assurance.

### 1. PRD First

Before implementing features:
1. Update `docs/prd.md` with requirements
2. Include detailed specifications: UI behavior, data structures, edge cases
3. Keep both language versions in sync

### 2. Technical Design

After PRD is finalized:
1. Update `docs/technical-design.md`
2. Document: data models, component design, state management, key flows
3. Include code snippets showing the expected implementation

### 3. Implementation with Reviews

Use the custom reviewer agents for quality assurance:

```
# After updating PRD, get product review
Use prd-implementation-reconciler agent to review

# After implementation, get technical review
Use swift-macos-code-reviewer agent to review

# Iterate based on feedback
```

### 4. Workflow Example

```
User: "Add bulk delete feature"

1. Update PRD with bulk delete specification
2. Run prd-implementation-reconciler → Get feedback → Update PRD
3. Update Technical Design with implementation details
4. Run tech-decision-reviewer → Get feedback → Update design
5. Implement the feature
6. Run swift-macos-code-reviewer → Fix issues
7. Run prd-implementation-reconciler → Verify alignment
8. Commit
```

---

## Reviewer Agents

Custom agents are defined in `.claude/agents/` for specialized reviews:

### swift-macos-code-reviewer

Technical code review for Swift/macOS:
- Swift best practices and concurrency patterns
- SwiftUI state management
- Memory management and retain cycles
- macOS HIG compliance

**When to use**: After implementing or modifying Swift code

### prd-implementation-reconciler

Product-level consistency check:
- Verify implementation matches PRD specifications
- Check UI behavior alignment
- Validate feature completeness

**When to use**: After implementing features, before commits

### tech-decision-reviewer

Technical design review:
- Architecture decisions
- Technology choices
- System design evaluation

**When to use**: When making foundational technical decisions

### requirements-reviewer

Requirements analysis:
- PRD review and summarization
- Development guidelines extraction

**When to use**: Before starting new feature implementation

---

## Code Style Guidelines

- Use Swift naming conventions (PascalCase for types, camelCase for properties)
- Match file names to primary type names
- Use `@MainActor` for all UI-related classes
- Prefer `async/await` over callbacks
- Use `[weak self]` in closures that capture self
- Document public APIs with `///` comments
