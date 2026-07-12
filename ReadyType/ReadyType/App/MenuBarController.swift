import AppKit
import SwiftUI

enum MenuBarPopoverLayout {
    static let width: CGFloat = 318
    static let height: CGFloat = 430
}

@MainActor
final class MenuBarController: NSObject, NSPopoverDelegate {
    private let statusItem: NSStatusItem
    private let appState: AppState
    private let openConsole: @MainActor () -> Void
    private let popover = NSPopover()
    private var escapeMonitor: Any?

    init(appState: AppState, openConsole: @escaping @MainActor () -> Void = MenuBarController.defaultOpenSettings) {
        self.appState = appState
        self.openConsole = openConsole
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        configureStatusItem()
        configurePopover()
    }

    private func configureStatusItem() {
        statusItem.button?.image = Self.menuBarIcon()
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.title = ""
        statusItem.button?.toolTip = "ReadyType"
        statusItem.button?.setAccessibilityLabel("ReadyType")
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover(_:))
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.delegate = self
        popover.animates = true
        popover.contentSize = NSSize(
            width: MenuBarPopoverLayout.width,
            height: MenuBarPopoverLayout.height
        )
        popover.contentViewController = NSHostingController(
            rootView: MenuBarPopoverView(
                appState: appState,
                openConsole: { [weak self] in
                    self?.popover.performClose(nil)
                    self?.openConsole()
                },
                quit: {
                    NSApp.terminate(nil)
                }
            )
        )
    }

    private static func menuBarIcon() -> NSImage? {
        guard let url = resourceURL(forResource: "ReadyTypeMenuBarTemplate", withExtension: "png"),
              let image = NSImage(contentsOf: url)
        else {
            return nil
        }

        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = true
        return image
    }

    private static func resourceURL(forResource name: String, withExtension fileExtension: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: fileExtension)
            ?? Bundle.module.url(forResource: name, withExtension: fileExtension)
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else {
            return
        }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    func popoverDidShow(_ notification: Notification) {
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return event }
            self?.popover.performClose(nil)
            return nil
        }
    }

    func popoverWillClose(_ notification: Notification) {
        if let escapeMonitor {
            NSEvent.removeMonitor(escapeMonitor)
            self.escapeMonitor = nil
        }
    }

    private static func defaultOpenSettings() {
        if #available(macOS 13.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }

        NSApp.activate(ignoringOtherApps: true)
    }
}
