# Clocklet

A lightweight macOS menu bar app for tracking work hours. Designed for freelancers and self-employed individuals who need simple, distraction-free time tracking.

## Features

- **One-Click Tracking**: Clock in/out directly from the menu bar
- **Global Shortcut**: Configure a keyboard shortcut for quick access
- **Daily & Monthly Summaries**: View your work hours at a glance
- **Reminder Notifications**: Get notified if you forget to clock out
- **History Management**: View, edit, and bulk delete past entries
- **Sleep Detection**: Automatically clock out when your Mac sleeps (configurable)
- **Crash Recovery**: Sessions are preserved even if the app crashes

## Screenshots

*Coming soon*

## Requirements

- macOS 15.0 (Sequoia) or later
- Apple Silicon or Intel Mac

## Installation

### From Source

1. Clone the repository:
   ```bash
   git clone https://github.com/5n7/clocklet.git
   cd clocklet
   ```

2. Open in Xcode:
   ```bash
   open Clocklet/Clocklet.xcodeproj
   ```

3. Build and run (⌘R)

### Releases

*Coming soon*

## Usage

1. **Clock In**: Click the clock icon in the menu bar and select "Clock In"
2. **Clock Out**: Click again and select "Clock Out"
3. **View History**: Access your time entries from the menu
4. **Settings**: Configure shortcuts, reminders, and other preferences

### Keyboard Shortcut

Set a global shortcut in Settings to toggle clock in/out from anywhere.

### Data Storage

Your time entries are stored locally at:
```
~/Library/Application Support/Clocklet/data.json
```

The data is human-readable JSON and can be manually edited if needed.

## Development

### Tech Stack

- **Language**: Swift
- **UI**: SwiftUI + AppKit
- **Architecture**: MVVM with @Observable
- **Data**: JSON file with Codable
- **Dependencies**: Swift Package Manager

### Building

```bash
# Build
xcodebuild -scheme Clocklet -configuration Debug build

# Run tests
xcodebuild -scheme Clocklet test
```

### Project Structure

```
Clocklet/
├── Models/          # Data models (TimeEntry, ClockletData)
├── ViewModels/      # Business logic (ClockViewModel)
├── Views/           # SwiftUI views
├── Services/        # DataStore, Notifications, Settings
└── Utilities/       # Formatters and helpers
```

## Documentation

- [Product Requirements (EN)](docs/prd.md)
- [Technical Design (EN)](docs/technical-design.md)

## License

MIT License - see [LICENSE](LICENSE) for details.

## Contributing

Contributions are welcome! Please read the documentation before submitting PRs.

## Acknowledgments

- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) by Sindre Sorhus
- [LaunchAtLogin](https://github.com/sindresorhus/LaunchAtLogin) by Sindre Sorhus
