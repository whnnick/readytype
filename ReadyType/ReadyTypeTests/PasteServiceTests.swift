import XCTest
@testable import ReadyType

@MainActor
final class PasteServiceTests: XCTestCase {
    func testPasteWritesClipboardAndReturnsPastedWhenAutomaticPasteSucceeds() throws {
        let clipboard = InMemoryClipboard()
        let directTextInserter = MockDirectTextInserter(result: false)
        let pasteInvoker = MockPasteInvoker(result: true)
        let targetActivator = MockPasteTargetActivator(result: true)
        let service = PasteService(
            clipboard: clipboard,
            directTextInserter: directTextInserter,
            pasteInvoker: pasteInvoker,
            pasteTargetActivator: targetActivator
        )

        let result = try service.deliver("final output", pasteAutomatically: true)

        XCTAssertEqual(result, .pasted)
        XCTAssertEqual(clipboard.string, "final output")
        XCTAssertEqual(targetActivator.prepareCount, 1)
        XCTAssertEqual(directTextInserter.requests, ["final output"])
        XCTAssertEqual(pasteInvoker.invokeCount, 1)
    }

    func testPasteUsesDirectTextInsertionBeforeKeyboardPaste() throws {
        let clipboard = InMemoryClipboard()
        let directTextInserter = MockDirectTextInserter(result: true)
        let pasteInvoker = MockPasteInvoker(result: true)
        let targetActivator = MockPasteTargetActivator(result: true)
        let service = PasteService(
            clipboard: clipboard,
            directTextInserter: directTextInserter,
            pasteInvoker: pasteInvoker,
            pasteTargetActivator: targetActivator
        )

        let result = try service.deliver("final output", pasteAutomatically: true)

        XCTAssertEqual(result, .pasted)
        XCTAssertNil(clipboard.string)
        XCTAssertEqual(targetActivator.prepareCount, 1)
        XCTAssertEqual(directTextInserter.requests, ["final output"])
        XCTAssertEqual(pasteInvoker.invokeCount, 0)
    }

    func testPasteWritesClipboardAndReturnsCopiedFallbackWhenAutomaticPasteFails() throws {
        let clipboard = InMemoryClipboard()
        let directTextInserter = MockDirectTextInserter(result: false)
        let pasteInvoker = MockPasteInvoker(result: false)
        let targetActivator = MockPasteTargetActivator(result: true)
        let service = PasteService(
            clipboard: clipboard,
            directTextInserter: directTextInserter,
            pasteInvoker: pasteInvoker,
            pasteTargetActivator: targetActivator
        )

        let result = try service.deliver("final output", pasteAutomatically: true)

        XCTAssertEqual(result, .copiedFallback)
        XCTAssertEqual(clipboard.string, "final output")
        XCTAssertEqual(targetActivator.prepareCount, 1)
        XCTAssertEqual(directTextInserter.requests, ["final output"])
        XCTAssertEqual(pasteInvoker.invokeCount, 1)
    }

    func testPasteCopiesWithoutInvokingPasteWhenTargetCannotBeActivated() throws {
        let clipboard = InMemoryClipboard()
        let directTextInserter = MockDirectTextInserter(result: true)
        let pasteInvoker = MockPasteInvoker(result: true)
        let targetActivator = MockPasteTargetActivator(result: false)
        let service = PasteService(
            clipboard: clipboard,
            directTextInserter: directTextInserter,
            pasteInvoker: pasteInvoker,
            pasteTargetActivator: targetActivator
        )

        let result = try service.deliver("final output", pasteAutomatically: true)

        XCTAssertEqual(result, .copiedFallback)
        XCTAssertEqual(clipboard.string, "final output")
        XCTAssertEqual(targetActivator.prepareCount, 1)
        XCTAssertTrue(directTextInserter.requests.isEmpty)
        XCTAssertEqual(pasteInvoker.invokeCount, 0)
    }

    func testPasteOnlyCopiesWhenAutomaticPasteDisabled() throws {
        let clipboard = InMemoryClipboard()
        let directTextInserter = MockDirectTextInserter(result: true)
        let pasteInvoker = MockPasteInvoker(result: true)
        let targetActivator = MockPasteTargetActivator(result: true)
        let service = PasteService(
            clipboard: clipboard,
            directTextInserter: directTextInserter,
            pasteInvoker: pasteInvoker,
            pasteTargetActivator: targetActivator
        )

        let result = try service.deliver("final output", pasteAutomatically: false)

        XCTAssertEqual(result, .copiedFallback)
        XCTAssertEqual(clipboard.string, "final output")
        XCTAssertEqual(targetActivator.prepareCount, 0)
        XCTAssertTrue(directTextInserter.requests.isEmpty)
        XCTAssertEqual(pasteInvoker.invokeCount, 0)
    }

    func testPasteRejectsEmptyOutputBeforeClipboardWrite() {
        let clipboard = InMemoryClipboard()
        let directTextInserter = MockDirectTextInserter(result: true)
        let pasteInvoker = MockPasteInvoker(result: true)
        let targetActivator = MockPasteTargetActivator(result: true)
        let service = PasteService(
            clipboard: clipboard,
            directTextInserter: directTextInserter,
            pasteInvoker: pasteInvoker,
            pasteTargetActivator: targetActivator
        )

        do {
            _ = try service.deliver("   ", pasteAutomatically: true)
            XCTFail("Expected pasteFailed")
        } catch let error as ReadyTypeError {
            XCTAssertEqual(error, .pasteFailed)
            XCTAssertNil(clipboard.string)
            XCTAssertEqual(targetActivator.prepareCount, 0)
            XCTAssertTrue(directTextInserter.requests.isEmpty)
            XCTAssertEqual(pasteInvoker.invokeCount, 0)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSystemPasteInvokerDoesNotReportCGEventSuccessWhenAccessibilityIsMissing() {
        let invoker = SystemPasteInvoker(
            accessibilityTrusted: { false },
            systemEventsPaste: { false },
            cgEventPaste: { true }
        )

        XCTAssertFalse(invoker.invokePaste())
    }

    func testSystemPasteInvokerCanUseCGEventWhenAccessibilityIsTrusted() {
        let invoker = SystemPasteInvoker(
            accessibilityTrusted: { true },
            systemEventsPaste: { false },
            cgEventPaste: { true }
        )

        XCTAssertTrue(invoker.invokePaste())
    }

    func testSystemPasteInvokerKeepsSystemEventsSuccessPath() {
        let invoker = SystemPasteInvoker(
            accessibilityTrusted: { false },
            systemEventsPaste: { true },
            cgEventPaste: { false }
        )

        XCTAssertTrue(invoker.invokePaste())
    }

    func testDirectInsertionDoesNotTreatUnreadableAXValueAsSuccess() {
        XCTAssertFalse(DirectInsertionVerification.didUnicodeTypingChangeValue(initialValue: nil, finalValue: nil))
        XCTAssertFalse(DirectInsertionVerification.didUnicodeTypingChangeValue(initialValue: "before", finalValue: nil))
        XCTAssertFalse(DirectInsertionVerification.didUnicodeTypingChangeValue(initialValue: "before", finalValue: "before"))
        XCTAssertTrue(DirectInsertionVerification.didUnicodeTypingChangeValue(initialValue: "before", finalValue: "beforeafter"))
    }

    func testPasteTargetCandidateRejectsReadyTypeAndLoginWindow() {
        XCTAssertTrue(SystemPasteTargetActivator.isPasteTargetCandidate(
            bundleIdentifier: "com.apple.TextEdit",
            activationPolicy: .regular,
            isReadyType: false
        ))
        XCTAssertFalse(SystemPasteTargetActivator.isPasteTargetCandidate(
            bundleIdentifier: "com.readytype.ReadyType",
            activationPolicy: .regular,
            isReadyType: true
        ))
        XCTAssertFalse(SystemPasteTargetActivator.isPasteTargetCandidate(
            bundleIdentifier: "com.apple.loginwindow",
            activationPolicy: .regular,
            isReadyType: false
        ))
        XCTAssertFalse(SystemPasteTargetActivator.isPasteTargetCandidate(
            bundleIdentifier: "com.apple.TextEdit",
            activationPolicy: .accessory,
            isReadyType: false
        ))
    }
}

private final class InMemoryClipboard: ClipboardWriting {
    private(set) var string: String?

    func writeString(_ string: String) throws {
        self.string = string
    }
}

private final class MockPasteInvoker: PasteInvoking {
    private let result: Bool
    private(set) var invokeCount = 0

    init(result: Bool) {
        self.result = result
    }

    func invokePaste() -> Bool {
        invokeCount += 1
        return result
    }
}

private final class MockDirectTextInserter: DirectTextInserting {
    private let result: Bool
    private(set) var requests: [String] = []

    init(result: Bool) {
        self.result = result
    }

    func insert(_ text: String) -> Bool {
        requests.append(text)
        return result
    }
}

private final class MockPasteTargetActivator: PasteTargetActivating {
    private let result: Bool
    private(set) var captureCount = 0
    private(set) var prepareCount = 0

    init(result: Bool) {
        self.result = result
    }

    func captureCurrentTarget() {
        captureCount += 1
    }

    func prepareForPaste() -> Bool {
        prepareCount += 1
        return result
    }
}
