# AGENTS.md

## Project Overview

FocusSlot is a lightweight macOS menu bar app for adding `[Task]` calendar events as time blocks.

The app is intentionally local-first:

- No backend.
- No database.
- No cloud sync beyond whatever macOS Calendar already syncs.
- Calendar is the source of truth.
- Native macOS Calendar accounts are accessed through EventKit.

The current architecture is hybrid:

- Swift/AppKit owns the menu bar item, right-click context menu, popover host, EventKit access, settings persistence, and scheduling logic.
- React/Vite/TypeScript owns the popover frontend UI.
- `WKWebView` embeds the built React app in the native popover.
- A typed JS-to-Swift bridge connects React actions to native calendar operations.

## Repository Layout

- `Package.swift`: Swift package definition.
- `Sources/FocusSlotCore`: pure Swift core logic and models.
- `Sources/FocusSlot`: native macOS app shell, EventKit controller, web bridge, logging.
- `frontend`: React/Vite/TypeScript frontend.
- `frontend/src/components/ui`: real shadcn/ui generated components.
- `frontend/src/ui/app.tsx`: main React app UI.
- `frontend/src/lib/native.ts`: JS-to-Swift bridge helper.
- `Resources/Info.plist`: app bundle metadata and calendar permission strings.
- `scripts/build-app.sh`: builds frontend, builds Swift release binary, packages `.app`.
- `Tests/FocusSlotCoreTests`: tests for scheduling and task title/category formatting.

## Core Product Behavior

FocusSlot lives in the macOS menu bar.

Left-click:

- Opens/closes the popover.

Right-click or control-click:

- Opens a context menu with open/close, calendar settings, logs, and quit.

The UI supports:

- Day filtering with `Today`, `Tomorrow`, and `Custom`.
- Custom date selection using shadcn `Popover` + `Calendar`.
- Viewing `[Task]` events for the selected day.
- Creating tasks with title, category, and duration.
- Editing existing task title, category, start time, and duration.
- Marking tasks done.
- Moving tasks to the next available slot.
- Deleting tasks.
- Editing local settings.

Task categories are:

- `CS`
- `Bugs`
- `Feature`
- `Pair`
- `Investigation`

Calendar event title format:

- Legacy/uncategorized: `[Task] My task`
- Categorized: `[Task] [Bugs] My task`
- Done: `✅ [Task] [Bugs] My task`

The parser must stay backward-compatible with older `[Task] My task` events.

## Native Swift Architecture

Important files:

- `Sources/FocusSlot/FocusSlotApp.swift`: app entry point and app delegate.
- `Sources/FocusSlot/StatusBarController.swift`: `NSStatusItem`, left-click popover, right-click menu.
- `Sources/FocusSlot/WebPopoverViewController.swift`: `WKWebView` host and bridge command router.
- `Sources/FocusSlot/WebBridgeModels.swift`: DTOs serialized between Swift and React.
- `Sources/FocusSlot/CalendarController.swift`: EventKit permissions, calendar fetching, task mutations.
- `Sources/FocusSlot/SettingsStore.swift`: `UserDefaults` persistence for scheduling settings.
- `Sources/FocusSlot/FocusSlotLogger.swift`: logs native and frontend errors.
- `Sources/FocusSlotCore/SchedulingService.swift`: pure scheduling logic.
- `Sources/FocusSlotCore/TaskTitleFormatter.swift`: `[Task]`, done marker, category parsing/formatting.
- `Sources/FocusSlotCore/TaskCategory.swift`: supported category enum.

Keep scheduling logic pure and testable in `FocusSlotCore`.

Keep EventKit, permissions, and system side effects in `Sources/FocusSlot`.

## React Frontend Architecture

Important files:

- `frontend/src/main.tsx`: React mount, error boundary, frontend-ready signal.
- `frontend/src/ui/app.tsx`: main UI and bridge calls.
- `frontend/src/ui/error-boundary.tsx`: visible fallback for React render crashes.
- `frontend/src/lib/native.ts`: `sendNative` bridge helper.
- `frontend/src/lib/types.ts`: frontend copies of bridge DTO shapes.
- `frontend/src/lib/utils.ts`: `cn` plus date formatting/input helpers.
- `frontend/src/styles.css`: Tailwind/shadcn theme and app-level CSS.
- `frontend/components.json`: shadcn CLI config.

Use real shadcn components through the CLI, not hand-written lookalikes.

Generated shadcn components currently used:

- `button`
- `card`
- `input`
- `badge`
- `native-select`
- `separator`
- `tabs`
- `popover`
- `calendar`

Add more components with commands like:

```sh
cd frontend
npx shadcn@latest add button
```

This project follows the Vite shadcn setup with `@/*` mapped to `frontend/src/*`.

## JS-to-Swift Bridge

React calls Swift via:

```ts
sendNative(type, payload)
```

Bridge implementation:

- JS side: `frontend/src/lib/native.ts`
- Swift side: `Sources/FocusSlot/WebPopoverViewController.swift`

Current command types:

- `initialize`
- `loadEvents`
- `addTask`
- `updateTask`
- `markDone`
- `moveNext`
- `deleteTask`
- `updateSettings`
- `openCalendarSettings`

Internal logging messages:

- `__frontendReady`
- `__log`

When adding bridge commands:

1. Add/update the frontend type in `frontend/src/lib/types.ts`.
2. Add the payload DTO in `Sources/FocusSlot/WebBridgeModels.swift`.
3. Add routing in `WebPopoverViewController.handleRequest`.
4. Return a fresh `WebAppState` after mutations when the UI needs to refresh.

## Calendar Behavior

EventKit reads all events for the selected day.

Task events are only managed from the configured writable task calendar.

Other calendar events still block scheduling.

This is deliberate because each Mac can choose a different task calendar, while busy time should still reflect all synced calendars.

Settings are stored locally in `UserDefaults`:

- selected calendar identifier
- workday start/end
- lunch start/end
- buffer minutes
- slot granularity
- auto-rebalance flag

## Scheduling Rules

Implemented in `SchedulingService`.

Rules:

- Past days cannot be scheduled.
- Today starts no earlier than now rounded up to the configured granularity plus buffer.
- Future days start at configured workday start.
- Lunch window is excluded.
- Fixed events and existing tasks block time.
- Busy intervals are expanded by buffer minutes.
- Candidate slots are scored, not just first-fit.

Tests cover:

- future day workday start
- today rounding plus buffer
- busy interval avoidance
- lunch exclusion
- past day rejection

## Build And Test Commands

Frontend only:

```sh
cd frontend
npm run build
```

Swift tests:

```sh
swift test
```

Full app bundle:

```sh
./scripts/build-app.sh
open dist/FocusSlot.app
```

`scripts/build-app.sh` builds the React frontend, builds the Swift release binary, and copies `frontend/dist` into:

```txt
dist/FocusSlot.app/Contents/Resources/frontend
```

If SwiftPM fails under sandboxing because it needs cache access outside the workspace, rerun with escalated permissions.

If npm needs packages or shadcn components, network access is required.

## Debugging

The app writes logs to:

```txt
~/Library/Application Support/FocusSlot/FocusSlot.log
```

The tray right-click menu has `Open Logs`.

Logged events include:

- frontend asset loading
- `WKWebView` navigation success/failure
- frontend ready signal
- JS `console.*`
- `window.onerror`
- unhandled promise rejections
- native bridge command failures

If the popover is blank white:

1. Right-click tray icon.
2. Choose `Open Logs`.
3. Check for frontend load errors, JS errors, or bridge errors.
4. Confirm the built bundle contains `Contents/Resources/frontend/index.html`.

React render crashes should show a visible error card from `ErrorBoundary` instead of a blank panel.

## Implementation Preferences

- Keep native/system integration in Swift.
- Keep UI iteration in React.
- Keep scheduling logic pure and tested.
- Prefer shadcn-generated components over custom primitives.
- Avoid backend/cloud/database features unless explicitly requested.
- Preserve compatibility with existing `[Task]` calendar events.
- Do not change the calendar event title format casually; it is the persistence format.
- Avoid broad refactors unless they simplify the bridge or isolate testable logic.

## Current Known Notes

- The app is packaged manually by `scripts/build-app.sh`, not Xcode.
- `WKWebView` loads local `index.html` from bundled resources in the app bundle.
- In local development, the web view can also load `frontend/dist/index.html` from the current working directory if the bundled copy is not present.
- Calendar access denial usually cannot re-trigger the Apple permission prompt until the user enables access in System Settings.
- The shadcn CLI may update `src/styles.css` and generated components. Review generated changes before making UI-specific edits.
