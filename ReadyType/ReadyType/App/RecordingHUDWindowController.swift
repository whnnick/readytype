import AppKit
import SwiftUI

@MainActor
final class RecordingHUDWindowController {
    private let appState: AppState
    private var panel: NSPanel?
    private var hideTask: Task<Void, Never>?
    private var recordingStartedAt = Date()
    private var lastRuntimeState: RuntimeState = .idle

    init(appState: AppState) {
        self.appState = appState
    }

    func update() {
        let state = appState.runtimeState

        if state == .recording && lastRuntimeState != .recording {
            recordingStartedAt = Date()
        }

        lastRuntimeState = state

        switch state {
        case .idle:
            hideImmediately()
        case .recording, .transcribing, .processingAI:
            hideTask?.cancel()
            showOrRefresh()
        case .pasted:
            showOrRefresh()
            scheduleHide(after: 0.9)
        case .copiedFallback:
            showOrRefresh()
            scheduleHide(after: 1.5)
        case .error:
            showOrRefresh()
            scheduleHide(after: 2.2)
        }
    }

    func hideImmediately() {
        hideTask?.cancel()
        hideTask = nil
        panel?.orderOut(nil)
    }

    private func showOrRefresh() {
        let panel = panel ?? makePanel()
        self.panel = panel

        panel.contentView = NSHostingView(
            rootView: RecordingHUDView(appState: appState, recordingStartedAt: recordingStartedAt)
                .preferredColorScheme(.dark)
        )
        let targetOrigin = targetOrigin(for: panel)

        if !panel.isVisible {
            let entranceOffset = MotionTokens.hudEntranceOffset(for: .current)
            panel.setFrameOrigin(NSPoint(x: targetOrigin.x, y: targetOrigin.y - entranceOffset))
            panel.alphaValue = 0
            panel.makeKeyAndOrderFront(nil)
            NSAnimationContext.runAnimationGroup { context in
                context.duration = MotionPreferences.current.reduceMotion ? 0.12 : 0.18
                panel.animator().alphaValue = 1
                panel.animator().setFrameOrigin(targetOrigin)
            }
        } else {
            panel.setFrameOrigin(targetOrigin)
        }
    }

    private func scheduleHide(after delay: TimeInterval) {
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(Int(delay * 1_000)))
            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                self?.fadeOut()
            }
        }
    }

    private func fadeOut() {
        guard let panel, panel.isVisible else {
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = MotionPreferences.current.reduceMotion ? 0.10 : 0.16
            panel.animator().alphaValue = 0
        } completionHandler: {
            Task { @MainActor in
                panel.orderOut(nil)
                panel.alphaValue = 1
            }
        }
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 590, height: 88),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        return panel
    }

    private func targetOrigin(for panel: NSPanel) -> NSPoint {
        guard let screen = NSScreen.main else {
            return panel.frame.origin
        }

        let frame = screen.visibleFrame
        let size = panel.frame.size
        return NSPoint(
            x: frame.midX - size.width / 2,
            y: frame.minY + 54
        )
    }
}
