import AppKit
import Combine
import SwiftUI

@MainActor
final class RecordingHUDPresentationState: ObservableObject {
    @Published private(set) var recordingStartedAt = Date()
    @Published private(set) var processingStartedAt = Date()
    @Published private(set) var isEscapeHintVisible = false

    func transition(
        from previousState: RuntimeState,
        to state: RuntimeState,
        now: Date = Date(),
        showsEscapeHint: Bool = false
    ) {
        if state == .recording && previousState != .recording {
            recordingStartedAt = now
            isEscapeHintVisible = showsEscapeHint
        }

        if state != previousState,
           state == .transcribing || state == .processingAI {
            processingStartedAt = now
        }
    }

    func dismissEscapeHint() {
        isEscapeHintVisible = false
    }
}

@MainActor
final class EscapeHintReminderStore {
    private static let lastActivationKey = "readyTypeLastEscapeHintActivationAt"

    private let defaults: UserDefaults
    private let calendar: Calendar

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
    }

    func shouldShowHint(at now: Date) -> Bool {
        guard let lastActivationAt = defaults.object(forKey: Self.lastActivationKey) as? Date else {
            return true
        }
        return !calendar.isDate(lastActivationAt, inSameDayAs: now)
    }

    func recordActivation(at date: Date) {
        defaults.set(date, forKey: Self.lastActivationKey)
    }
}

@MainActor
final class RecordingHUDWindowController {
    private let appState: AppState
    private let audioLevelProvider: () -> Double
    private let onCancel: () -> Void
    private let escapeHintReminderStore: EscapeHintReminderStore
    private let presentationState = RecordingHUDPresentationState()
    private var panel: NSPanel?
    private var hideTask: Task<Void, Never>?
    private var escapeHintTask: Task<Void, Never>?
    private var lastRuntimeState: RuntimeState = .idle

    init(
        appState: AppState,
        audioLevelProvider: @escaping () -> Double = { 0 },
        onCancel: @escaping () -> Void = {},
        escapeHintReminderStore: EscapeHintReminderStore = EscapeHintReminderStore()
    ) {
        self.appState = appState
        self.audioLevelProvider = audioLevelProvider
        self.onCancel = onCancel
        self.escapeHintReminderStore = escapeHintReminderStore
    }

    func update() {
        let state = appState.runtimeState
        let now = Date()
        let beginsRecording = state == .recording && lastRuntimeState != .recording
        let showsEscapeHint = beginsRecording && escapeHintReminderStore.shouldShowHint(at: now)
        presentationState.transition(
            from: lastRuntimeState,
            to: state,
            now: now,
            showsEscapeHint: showsEscapeHint
        )
        if beginsRecording {
            escapeHintReminderStore.recordActivation(at: now)
        }
        if presentationState.isEscapeHintVisible {
            scheduleEscapeHintDismissal()
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
        escapeHintTask?.cancel()
        escapeHintTask = nil
        presentationState.dismissEscapeHint()
        panel?.orderOut(nil)
    }

    private func scheduleEscapeHintDismissal() {
        escapeHintTask?.cancel()
        escapeHintTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(MotionTokens.escapeHintDuration))
            guard !Task.isCancelled else {
                return
            }
            self?.presentationState.dismissEscapeHint()
        }
    }

    private func showOrRefresh() {
        let panel = panel ?? makePanel()
        self.panel = panel
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
            contentRect: NSRect(origin: .zero, size: MotionTokens.voiceCapsuleWindowSize),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.contentView = NSHostingView(
            rootView: RecordingHUDView(
                appState: appState,
                presentationState: presentationState,
                audioLevelProvider: audioLevelProvider,
                onCancel: onCancel
            )
        )
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
