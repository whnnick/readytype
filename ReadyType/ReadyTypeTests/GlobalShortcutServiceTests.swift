import XCTest
@testable import ReadyType

final class GlobalShortcutServiceTests: XCTestCase {
    func testStartRegistersMonitorAndDispatchesToggleOnDoublePressOnly() throws {
        let monitor = MockShortcutEventMonitor()
        var events: [String] = []
        var now = Date(timeIntervalSince1970: 1_000)
        let service = GlobalShortcutService(
            monitor: monitor,
            timeProvider: { now },
            onToggle: { events.append("toggle") }
        )

        try service.start()
        monitor.emit(.pressed)
        monitor.emit(.released)
        XCTAssertEqual(events, [])

        now = now.addingTimeInterval(0.25)
        monitor.emit(.pressed)
        monitor.emit(.released)

        XCTAssertEqual(monitor.startCount, 1)
        XCTAssertEqual(events, ["toggle"])
    }

    func testRepeatedPressDoesNotToggleUntilReleasedAndDoublePressedAgain() throws {
        let monitor = MockShortcutEventMonitor()
        var events: [String] = []
        var now = Date(timeIntervalSince1970: 1_000)
        let service = GlobalShortcutService(
            monitor: monitor,
            timeProvider: { now },
            onToggle: { events.append("toggle") }
        )

        try service.start()
        monitor.emit(.pressed)
        monitor.emit(.pressed)
        monitor.emit(.pressed)
        monitor.emit(.released)
        XCTAssertEqual(events, [])

        now = now.addingTimeInterval(0.2)
        monitor.emit(.pressed)
        monitor.emit(.released)

        XCTAssertEqual(events, ["toggle"])
    }

    func testDoublePressExpiresWhenSecondPressIsTooLate() throws {
        let monitor = MockShortcutEventMonitor()
        var events: [String] = []
        var now = Date(timeIntervalSince1970: 1_000)
        let service = GlobalShortcutService(
            monitor: monitor,
            timeProvider: { now },
            onToggle: { events.append("toggle") }
        )

        try service.start()
        monitor.emit(.pressed)
        monitor.emit(.released)

        now = now.addingTimeInterval(0.8)
        monitor.emit(.pressed)
        monitor.emit(.released)

        XCTAssertEqual(events, [])
    }

    func testStopStopsMonitorAndClearsPressedState() throws {
        let monitor = MockShortcutEventMonitor()
        var events: [String] = []
        var now = Date(timeIntervalSince1970: 1_000)
        let service = GlobalShortcutService(
            monitor: monitor,
            timeProvider: { now },
            onToggle: { events.append("toggle") }
        )

        try service.start()
        monitor.emit(.pressed)
        monitor.emit(.released)
        now = now.addingTimeInterval(0.2)
        monitor.emit(.pressed)
        monitor.emit(.released)
        service.stop()
        monitor.emit(.pressed)

        XCTAssertEqual(monitor.stopCount, 1)
        XCTAssertEqual(events, ["toggle"])
    }

    func testStartMapsMonitorFailureToShortcutRegistrationError() {
        let monitor = MockShortcutEventMonitor(error: ReadyTypeError.shortcutRegistrationFailed)
        let service = GlobalShortcutService(monitor: monitor, onToggle: {})

        XCTAssertThrowsError(try service.start()) { error in
            XCTAssertEqual(error as? ReadyTypeError, .shortcutRegistrationFailed)
        }
    }

    func testDefaultShortcutUsesOptionModifierOnly() {
        XCTAssertEqual(ModifierChord.option.modifiers, [.option])
    }

    func testVoiceShortcutConfigurationMapsToModifierChord() {
        XCTAssertEqual(VoiceShortcutTrigger.doubleOption.modifierChord, .option)
        XCTAssertEqual(VoiceShortcutTrigger.doubleControl.modifierChord, .control)
        XCTAssertEqual(VoiceShortcutTrigger.doubleCommand.modifierChord, .command)
        XCTAssertEqual(VoiceShortcutTrigger.doubleFunction.modifierChord, .fn)
    }

    func testVoiceShortcutConfigurationUsesPlainUserFacingNames() {
        XCTAssertEqual(VoiceShortcutTrigger.doubleOption.displayName, "双击 Option")
        XCTAssertEqual(VoiceShortcutTrigger.doubleControl.displayName, "双击 Control")
        XCTAssertEqual(VoiceShortcutConfiguration.default.displayName, "双击 Option")
    }

    func testDoubleFnShortcutStillMatchesFunctionModifierOnlyForCompatibility() {
        XCTAssertEqual(ModifierChord.fn.modifiers, [.function])
    }

    func testOptionShortcutMatchesOnlyOptionModifier() {
        XCTAssertTrue(ModifierChord.option.matches([.option]))
        XCTAssertTrue(ModifierChord.option.matches([.option, .capsLock]))
        XCTAssertFalse(ModifierChord.option.matches([.function, .option]))
        XCTAssertFalse(ModifierChord.option.matches([.function]))
    }

    func testControlAndCommandShortcutMatchOnlyTheirModifier() {
        XCTAssertTrue(ModifierChord.control.matches([.control]))
        XCTAssertTrue(ModifierChord.command.matches([.command]))
        XCTAssertFalse(ModifierChord.control.matches([.option]))
        XCTAssertFalse(ModifierChord.command.matches([.option]))
    }

    func testFnShortcutStillMatchesOnlyFunctionModifierForCompatibility() {
        XCTAssertTrue(ModifierChord.fn.matches([.function]))
        XCTAssertTrue(ModifierChord.fn.matches([.function, .capsLock]))
        XCTAssertFalse(ModifierChord.fn.matches([.function, .option]))
        XCTAssertFalse(ModifierChord.fn.matches([.option]))
    }

    func testEscapeCancelShortcutMatchesPlainEscapeOnly() {
        XCTAssertEqual(GlobalShortcut.escape.keyCode, 53)
        XCTAssertTrue(GlobalShortcut.escape.modifiers.isEmpty)
        XCTAssertTrue(EscapeKeyCancelMonitor.matchesEscape(keyCode: 53, modifierFlags: []))
        XCTAssertTrue(EscapeKeyCancelMonitor.matchesEscape(keyCode: 53, modifierFlags: [.capsLock]))
        XCTAssertFalse(EscapeKeyCancelMonitor.matchesEscape(keyCode: 53, modifierFlags: [.option]))
        XCTAssertFalse(EscapeKeyCancelMonitor.matchesEscape(keyCode: 36, modifierFlags: []))
    }

    func testCGEventTapShortcutMonitorMatchesPlainEscapeOnly() {
        XCTAssertTrue(CGEventTapShortcutMonitor.matches(keyCode: 53, modifierFlags: [], shortcut: .escape))
        XCTAssertTrue(CGEventTapShortcutMonitor.matches(keyCode: 53, modifierFlags: [.capsLock], shortcut: .escape))
        XCTAssertFalse(CGEventTapShortcutMonitor.matches(keyCode: 53, modifierFlags: [.option], shortcut: .escape))
        XCTAssertFalse(CGEventTapShortcutMonitor.matches(keyCode: 53, modifierFlags: [.command], shortcut: .escape))
        XCTAssertFalse(CGEventTapShortcutMonitor.matches(keyCode: 36, modifierFlags: [], shortcut: .escape))
    }

    func testCGEventTapShortcutMonitorRequiresAccessibilityTrust() {
        let monitor = CGEventTapShortcutMonitor(shortcut: .escape, accessibilityTrusted: { false })

        XCTAssertThrowsError(try monitor.start(handler: { _ in })) { error in
            XCTAssertEqual(error as? ReadyTypeError, .keyboardMonitoringPermissionMissing)
        }
    }

    func testEscapeKeyCancelMonitorCancelsOnPressedEventOnly() throws {
        let eventTapMonitor = MockShortcutEventMonitor()
        var cancelCount = 0
        let monitor = EscapeKeyCancelMonitor(
            eventTapMonitor: eventTapMonitor,
            onCancel: { cancelCount += 1 }
        )

        try monitor.start()
        eventTapMonitor.emit(.released)
        eventTapMonitor.emit(.pressed)

        XCTAssertEqual(cancelCount, 1)
    }

    func testRedundantShortcutMonitorFallsBackWhenPrimaryFails() throws {
        let primary = MockShortcutEventMonitor(error: ReadyTypeError.shortcutRegistrationFailed)
        let secondary = MockShortcutEventMonitor()
        let monitor = RedundantShortcutMonitor(primary: primary, secondary: secondary)
        var pressCount = 0

        try monitor.start { event in
            if event == .pressed {
                pressCount += 1
            }
        }
        secondary.emit(.pressed)
        monitor.stop()

        XCTAssertEqual(primary.stopCount, 1)
        XCTAssertEqual(secondary.startCount, 1)
        XCTAssertEqual(secondary.stopCount, 1)
        XCTAssertEqual(pressCount, 1)
    }
}

private final class MockShortcutEventMonitor: ShortcutEventMonitoring {
    private let error: Error?
    private var handler: ((ShortcutEvent) -> Void)?
    private(set) var startCount = 0
    private(set) var stopCount = 0

    init(error: Error? = nil) {
        self.error = error
    }

    func start(handler: @escaping (ShortcutEvent) -> Void) throws {
        if let error {
            throw error
        }

        startCount += 1
        self.handler = handler
    }

    func stop() {
        stopCount += 1
        handler = nil
    }

    func emit(_ event: ShortcutEvent) {
        handler?(event)
    }
}
