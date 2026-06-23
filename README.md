# FocusSlot

FocusSlot is a lightweight macOS menu bar app for adding `[Task]` time blocks to the native macOS Calendar.

It uses SwiftUI, `MenuBarExtra`, EventKit, and `UserDefaults`. There is no backend, database, account system, or third-party dependency. Any calendar account that is synced into the macOS Calendar app can be used by selecting its writable calendar in settings.

The menu bar shell and calendar bridge are native Swift/AppKit. The popover UI is a bundled React app rendered in `WKWebView`, using shadcn-style local components.

## Run

```sh
cd frontend && npm install && npm run build && cd ..
swift run FocusSlot
```

For normal macOS permissions and menu bar behavior, build an app bundle:

```sh
./scripts/build-app.sh
open dist/FocusSlot.app
```

## Test

```sh
swift test
```

## Configuration

Settings are stored locally in `UserDefaults`:

- task calendar
- workday start and end
- lunch start and end
- buffer minutes
- slot granularity
- auto-rebalance toggle

The selected calendar is stored by EventKit calendar identifier, so each Mac can point FocusSlot at a different local, iCloud, Google, or Exchange calendar.
