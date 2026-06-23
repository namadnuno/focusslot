import AppKit
import ServiceManagement

@MainActor
final class StatusBarController: NSObject {
    private let calendarController = CalendarController()
    private let settingsStore = SettingsStore()
    private let statusItem: NSStatusItem
    private let popover: NSPopover

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()

        super.init()

        configureStatusItem()
        configurePopover()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }

        button.image = NSImage(
            systemSymbolName: "calendar.badge.plus",
            accessibilityDescription: "FocusSlot"
        )
        button.image?.isTemplate = true
        button.target = self
        button.action = #selector(handleStatusItemClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 460, height: 680)
        popover.contentViewController = WebPopoverViewController(
            calendarController: calendarController,
            settingsStore: settingsStore
        )
    }

    @objc private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        let event = NSApplication.shared.currentEvent
        let isContextClick = event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true

        if isContextClick {
            showContextMenu(relativeTo: sender)
        } else {
            togglePopover(relativeTo: sender)
        }
    }

    private func togglePopover(relativeTo button: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover(relativeTo: button)
        }
    }

    private func showPopover(relativeTo button: NSStatusBarButton) {
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func showContextMenu(relativeTo button: NSStatusBarButton) {
        let menu = NSMenu()

        if popover.isShown {
            menu.addItem(
                NSMenuItem(
                    title: "Close Popover",
                    action: #selector(closePopover),
                    keyEquivalent: ""
                )
            )
        } else {
            menu.addItem(
                NSMenuItem(
                    title: "Open FocusSlot",
                    action: #selector(openPopoverFromMenu),
                    keyEquivalent: ""
                )
            )
        }

        menu.addItem(
            NSMenuItem(
                title: "Open Calendar Settings",
                action: #selector(openCalendarSettings),
                keyEquivalent: ""
            )
        )
        menu.addItem(
            NSMenuItem(
                title: "Open Logs",
                action: #selector(openLogs),
                keyEquivalent: ""
            )
        )
        menu.addItem(.separator())
        let loginItem = NSMenuItem(
            title: "Open at Login",
            action: #selector(toggleOpenAtLogin),
            keyEquivalent: ""
        )
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(loginItem)
        menu.addItem(.separator())
        menu.addItem(
            NSMenuItem(
                title: "Quit FocusSlot",
                action: #selector(quit),
                keyEquivalent: "q"
            )
        )

        for item in menu.items {
            item.target = self
        }

        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }

    @objc private func openPopoverFromMenu() {
        guard let button = statusItem.button else { return }
        showPopover(relativeTo: button)
    }

    @objc private func closePopover() {
        popover.performClose(nil)
    }

    @objc private func openCalendarSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    @objc private func openLogs() {
        FocusSlotLogger.log("Opening log file")
        NSWorkspace.shared.activateFileViewerSelecting([FocusSlotLogger.logFileURL])
    }

    @objc private func toggleOpenAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
                FocusSlotLogger.log("Disabled open at login")
            } else {
                try service.register()
                FocusSlotLogger.log("Enabled open at login")
            }
        } catch {
            FocusSlotLogger.log("Failed to toggle open at login: \(error.localizedDescription)")
            let alert = NSAlert()
            alert.messageText = "Couldn't change login setting"
            alert.informativeText =
                "\(error.localizedDescription)\n\nMake sure FocusSlot is in your Applications folder, then try again."
            alert.alertStyle = .warning
            alert.runModal()
        }
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
