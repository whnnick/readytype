import AppKit
import Carbon
import CoreGraphics
import Foundation

enum ShortcutEvent: Equatable {
    case pressed
    case released
}

struct GlobalShortcut: Equatable {
    let keyCode: UInt16
    let modifiers: NSEvent.ModifierFlags

    static let optionSpace = GlobalShortcut(
        keyCode: 49,
        modifiers: .option
    )

    static let escape = GlobalShortcut(
        keyCode: 53,
        modifiers: []
    )
}

struct ModifierChord: Equatable {
    let modifiers: NSEvent.ModifierFlags

    static let fn = ModifierChord(
        modifiers: [.function]
    )

    static let option = ModifierChord(
        modifiers: [.option]
    )

    static let control = ModifierChord(
        modifiers: [.control]
    )

    static let command = ModifierChord(
        modifiers: [.command]
    )

    static let fnOption = ModifierChord(
        modifiers: [.function, .option]
    )

    func matches(_ eventFlags: NSEvent.ModifierFlags) -> Bool {
        var normalizedFlags = eventFlags.intersection(.deviceIndependentFlagsMask)
        normalizedFlags.remove(.capsLock)
        return normalizedFlags == modifiers
    }
}

protocol ShortcutEventMonitoring: AnyObject {
    func start(handler: @escaping (ShortcutEvent) -> Void) throws
    func stop()
}

final class GlobalShortcutService {
    private let monitor: ShortcutEventMonitoring
    private let doublePressInterval: TimeInterval
    private let timeProvider: () -> Date
    private let onToggle: () -> Void
    private var isPressed = false
    private var lastPressAt: Date?

    init(
        monitor: ShortcutEventMonitoring = ModifierChordShortcutMonitor(chord: .option),
        doublePressInterval: TimeInterval = 0.45,
        timeProvider: @escaping () -> Date = Date.init,
        onToggle: @escaping () -> Void
    ) {
        self.monitor = monitor
        self.doublePressInterval = doublePressInterval
        self.timeProvider = timeProvider
        self.onToggle = onToggle
    }

    convenience init(
        configuration: VoiceShortcutConfiguration,
        timeProvider: @escaping () -> Date = Date.init,
        onToggle: @escaping () -> Void
    ) {
        self.init(
            monitor: ModifierChordShortcutMonitor(chord: configuration.trigger.modifierChord),
            doublePressInterval: configuration.doublePressInterval,
            timeProvider: timeProvider,
            onToggle: onToggle
        )
    }

    func start() throws {
        do {
            try monitor.start { [weak self] event in
                self?.handle(event)
            }
        } catch let error as ReadyTypeError {
            throw error
        } catch {
            throw ReadyTypeError.shortcutRegistrationFailed
        }
    }

    func stop() {
        monitor.stop()
        isPressed = false
        lastPressAt = nil
    }

    private func handle(_ event: ShortcutEvent) {
        switch event {
        case .pressed:
            guard !isPressed else {
                return
            }
            isPressed = true
            let now = timeProvider()
            if let lastPressAt, now.timeIntervalSince(lastPressAt) <= doublePressInterval {
                self.lastPressAt = nil
                onToggle()
            } else {
                lastPressAt = now
            }
        case .released:
            isPressed = false
        }
    }
}

final class EscapeKeyCancelMonitor {
    private let onCancel: () -> Void
    private let eventTapMonitor: ShortcutEventMonitoring

    init(
        eventTapMonitor: ShortcutEventMonitoring = RedundantShortcutMonitor(
            primary: CGEventTapShortcutMonitor(shortcut: .escape),
            secondary: NSEventShortcutMonitor(shortcut: .escape)
        ),
        onCancel: @escaping () -> Void
    ) {
        self.eventTapMonitor = eventTapMonitor
        self.onCancel = onCancel
    }

    func start() throws {
        stop()

        try eventTapMonitor.start { [weak self] event in
            guard event == .pressed else {
                return
            }
            self?.onCancel()
        }
    }

    func stop() {
        eventTapMonitor.stop()
    }

    static func matchesEscape(_ event: NSEvent) -> Bool {
        matchesEscape(keyCode: event.keyCode, modifierFlags: event.modifierFlags)
    }

    static func matchesEscape(keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags) -> Bool {
        var flags = modifierFlags.intersection(.deviceIndependentFlagsMask)
        flags.remove(.capsLock)
        return keyCode == 53 && flags.isEmpty
    }
}

final class CGEventTapShortcutMonitor: ShortcutEventMonitoring {
    private let shortcut: GlobalShortcut
    private let accessibilityTrusted: () -> Bool
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var handler: ((ShortcutEvent) -> Void)?

    init(
        shortcut: GlobalShortcut,
        accessibilityTrusted: @escaping () -> Bool = AXIsProcessTrusted
    ) {
        self.shortcut = shortcut
        self.accessibilityTrusted = accessibilityTrusted
    }

    func start(handler: @escaping (ShortcutEvent) -> Void) throws {
        stop()

        guard accessibilityTrusted() else {
            throw ReadyTypeError.keyboardMonitoringPermissionMissing
        }

        self.handler = handler

        let eventMask = Self.eventMask([.keyDown, .keyUp])

        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: Self.handleEventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            self.handler = nil
            throw ReadyTypeError.shortcutRegistrationFailed
        }

        guard let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0) else {
            CFMachPortInvalidate(eventTap)
            self.handler = nil
            throw ReadyTypeError.shortcutRegistrationFailed
        }

        self.eventTap = eventTap
        self.runLoopSource = runLoopSource
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    private static let handleEventTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else {
            return Unmanaged.passUnretained(event)
        }

        let monitor = Unmanaged<CGEventTapShortcutMonitor>
            .fromOpaque(userInfo)
            .takeUnretainedValue()

        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let eventTap = monitor.eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        case .keyDown, .keyUp:
            let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            let modifierFlags = NSEvent.ModifierFlags(rawValue: UInt(event.flags.rawValue))

            guard matches(keyCode: keyCode, modifierFlags: modifierFlags, shortcut: monitor.shortcut) else {
                return Unmanaged.passUnretained(event)
            }

            monitor.handler?(type == .keyDown ? .pressed : .released)
            return nil
        default:
            return Unmanaged.passUnretained(event)
        }
    }

    func stop() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }

        if let eventTap {
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }

        handler = nil
    }

    static func matches(
        keyCode: UInt16,
        modifierFlags: NSEvent.ModifierFlags,
        shortcut: GlobalShortcut
    ) -> Bool {
        var flags = modifierFlags.intersection(.deviceIndependentFlagsMask)
        flags.remove(.capsLock)
        return keyCode == shortcut.keyCode && flags == shortcut.modifiers
    }

    private static func eventMask(_ types: [CGEventType]) -> CGEventMask {
        types.reduce(0) { mask, type in
            mask | (1 << CGEventMask(type.rawValue))
        }
    }
}

final class ModifierChordShortcutMonitor: ShortcutEventMonitoring {
    private let chord: ModifierChord
    private var monitors: [Any] = []
    private var isActive = false

    init(chord: ModifierChord) {
        self.chord = chord
    }

    func start(handler: @escaping (ShortcutEvent) -> Void) throws {
        stop()

        let globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handle(event, handler: handler)
        }

        let localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handle(event, handler: handler)
            return event
        }

        if let globalMonitor {
            monitors.append(globalMonitor)
        }

        if let localMonitor {
            monitors.append(localMonitor)
        }

        guard monitors.count == 2 else {
            stop()
            throw ReadyTypeError.shortcutRegistrationFailed
        }
    }

    func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
        isActive = false
    }

    private func handle(_ event: NSEvent, handler: (ShortcutEvent) -> Void) {
        let matches = chord.matches(event.modifierFlags)

        if matches && !isActive {
            isActive = true
            handler(.pressed)
        } else if !matches && isActive {
            isActive = false
            handler(.released)
        }
    }
}

final class RedundantShortcutMonitor: ShortcutEventMonitoring {
    private let primary: ShortcutEventMonitoring
    private let secondary: ShortcutEventMonitoring
    private var didStartPrimary = false
    private var didStartSecondary = false

    init(primary: ShortcutEventMonitoring, secondary: ShortcutEventMonitoring) {
        self.primary = primary
        self.secondary = secondary
    }

    func start(handler: @escaping (ShortcutEvent) -> Void) throws {
        stop()

        var firstError: Error?

        do {
            try primary.start(handler: handler)
            didStartPrimary = true
        } catch {
            firstError = error
            primary.stop()
        }

        do {
            try secondary.start(handler: handler)
            didStartSecondary = true
        } catch {
            secondary.stop()
            if firstError == nil {
                firstError = error
            }
        }

        guard didStartPrimary || didStartSecondary else {
            throw firstError ?? ReadyTypeError.shortcutRegistrationFailed
        }
    }

    func stop() {
        if didStartPrimary {
            primary.stop()
            didStartPrimary = false
        }

        if didStartSecondary {
            secondary.stop()
            didStartSecondary = false
        }
    }
}

final class CarbonShortcutMonitor: ShortcutEventMonitoring {
    private let shortcut: GlobalShortcut
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var handler: ((ShortcutEvent) -> Void)?

    init(shortcut: GlobalShortcut) {
        self.shortcut = shortcut
    }

    func start(handler: @escaping (ShortcutEvent) -> Void) throws {
        stop()
        self.handler = handler

        var eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]

        let callback: EventHandlerUPP = { _, event, userData in
            guard let event, let userData else {
                return noErr
            }

            let monitor = Unmanaged<CarbonShortcutMonitor>
                .fromOpaque(userData)
                .takeUnretainedValue()
            let eventKind = GetEventKind(event)

            switch eventKind {
            case UInt32(kEventHotKeyPressed):
                monitor.handler?(.pressed)
            case UInt32(kEventHotKeyReleased):
                monitor.handler?(.released)
            default:
                break
            }

            return noErr
        }

        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            eventTypes.count,
            &eventTypes,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )

        guard handlerStatus == noErr else {
            stop()
            throw ReadyTypeError.shortcutRegistrationFailed
        }

        let hotKeyID = EventHotKeyID(signature: Self.fourCharacterCode("RTYP"), id: 1)
        let hotKeyStatus = RegisterEventHotKey(
            UInt32(shortcut.keyCode),
            Self.carbonModifiers(for: shortcut.modifiers),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard hotKeyStatus == noErr else {
            stop()
            throw ReadyTypeError.shortcutRegistrationFailed
        }
    }

    func stop() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }

        handler = nil
    }

    private static func carbonModifiers(for modifiers: NSEvent.ModifierFlags) -> UInt32 {
        var carbonModifiers: UInt32 = 0

        if modifiers.contains(.option) {
            carbonModifiers |= UInt32(optionKey)
        }

        if modifiers.contains(.command) {
            carbonModifiers |= UInt32(cmdKey)
        }

        if modifiers.contains(.control) {
            carbonModifiers |= UInt32(controlKey)
        }

        if modifiers.contains(.shift) {
            carbonModifiers |= UInt32(shiftKey)
        }

        return carbonModifiers
    }

    private static func fourCharacterCode(_ string: String) -> OSType {
        string.utf8.reduce(0) { result, character in
            (result << 8) + OSType(character)
        }
    }
}

final class NSEventShortcutMonitor: ShortcutEventMonitoring {
    private let shortcut: GlobalShortcut
    private var monitors: [Any] = []

    init(shortcut: GlobalShortcut) {
        self.shortcut = shortcut
    }

    func start(handler: @escaping (ShortcutEvent) -> Void) throws {
        stop()

        let globalKeyDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [shortcut] event in
            guard Self.matches(event, shortcut: shortcut) else {
                return
            }
            handler(.pressed)
        }

        let globalKeyUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyUp) { [shortcut] event in
            guard Self.matches(event, shortcut: shortcut) else {
                return
            }
            handler(.released)
        }

        let localKeyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [shortcut] event in
            guard Self.matches(event, shortcut: shortcut) else {
                return event
            }

            handler(.pressed)
            return nil
        }

        let localKeyUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyUp) { [shortcut] event in
            guard Self.matches(event, shortcut: shortcut) else {
                return event
            }

            handler(.released)
            return nil
        }

        if let globalKeyDownMonitor {
            monitors.append(globalKeyDownMonitor)
        }

        if let globalKeyUpMonitor {
            monitors.append(globalKeyUpMonitor)
        }

        if let localKeyDownMonitor {
            monitors.append(localKeyDownMonitor)
        }

        if let localKeyUpMonitor {
            monitors.append(localKeyUpMonitor)
        }

        guard monitors.count == 4 else {
            stop()
            throw ReadyTypeError.shortcutRegistrationFailed
        }
    }

    func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
    }

    private static func matches(_ event: NSEvent, shortcut: GlobalShortcut) -> Bool {
        event.keyCode == shortcut.keyCode &&
            event.modifierFlags
                .intersection(.deviceIndependentFlagsMask)
                .contains(shortcut.modifiers)
    }
}
