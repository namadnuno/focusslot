import AppKit
import SwiftUI

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
        let rootView = FocusSlotMenuView()
            .environmentObject(calendarController)
            .environmentObject(settingsStore)
            .frame(width: 430, height: 640)

        popover.behavior = .transient
        popover.contentSize = NSSize(width: 430, height: 640)
        popover.contentViewController = NSHostingController(rootView: rootView)
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

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
