import AppKit
import SwiftUI

@MainActor
final class MenuBarController {
    private let statusItem: NSStatusItem
    private let appState: AppState
    private let openConsole: @MainActor () -> Void
    private let popover = NSPopover()

    init(appState: AppState, openConsole: @escaping @MainActor () -> Void = MenuBarController.defaultOpenSettings) {
        self.appState = appState
        self.openConsole = openConsole
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
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
        popover.animates = true
        popover.appearance = NSAppearance(named: .darkAqua)
        popover.contentSize = NSSize(width: 292, height: 318)
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
            .preferredColorScheme(.dark)
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
            popover.contentViewController?.view.window?.makeKey()
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
