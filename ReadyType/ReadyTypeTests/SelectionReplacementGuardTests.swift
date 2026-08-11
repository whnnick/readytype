import Foundation
import XCTest
@testable import ReadyType

@MainActor
final class SelectionReplacementGuardTests: XCTestCase {
    func testFingerprintClassifiesAppFocusAndSelectionChanges() {
        let captured = makeContext(processIdentifier: 10, elementIdentifier: "editor", text: "原文")

        let appChanged = makeContext(processIdentifier: 11, elementIdentifier: "editor", text: "原文")
        XCTAssertEqual(captured.fingerprint.validationFailure(comparedTo: appChanged.fingerprint), .appChanged)

        let focusChanged = makeContext(processIdentifier: 10, elementIdentifier: "search", text: "原文")
        XCTAssertEqual(captured.fingerprint.validationFailure(comparedTo: focusChanged.fingerprint), .focusChanged)

        let rangeChanged = makeContext(
            processIdentifier: 10,
            elementIdentifier: "editor",
            text: "原文",
            range: TextSelectionRange(location: 4, length: 2)
        )
        XCTAssertEqual(captured.fingerprint.validationFailure(comparedTo: rangeChanged.fingerprint), .selectionChanged)

        let textChanged = makeContext(processIdentifier: 10, elementIdentifier: "editor", text: "新内容")
        XCTAssertEqual(captured.fingerprint.validationFailure(comparedTo: textChanged.fingerprint), .selectionChanged)

        XCTAssertNil(captured.fingerprint.validationFailure(comparedTo: captured.fingerprint))
    }

    func testPasteServiceCapturesOnlyThroughBoundedSelectionProvider() {
        let context = makeContext()
        let provider = MockActiveTextContextProvider(captureResult: .available(context))
        let service = makeService(provider: provider)

        let result = service.captureActiveTextContext(maximumCharacterCount: 8_000)

        XCTAssertEqual(result, .available(context))
        XCTAssertEqual(provider.captureLimits, [8_000])
    }

    func testUnchangedSelectionIsReplacedWithoutTouchingClipboard() throws {
        let context = makeContext()
        let clipboard = SelectionTestClipboard()
        let provider = MockActiveTextContextProvider(
            captureResult: .available(context),
            replacementAttempt: .replaced
        )
        let service = makeService(clipboard: clipboard, provider: provider)

        let result = try service.deliver(
            "修改后的内容",
            replacing: context,
            replaceAutomatically: true
        )

        XCTAssertEqual(result, .replaced)
        XCTAssertNil(clipboard.string)
        XCTAssertEqual(provider.replacementRequests.map(\.text), ["修改后的内容"])
    }

    func testEveryValidationFailureCopiesWithoutTryingAnotherTarget() throws {
        let failures: [SelectionValidationFailure] = [
            .appChanged,
            .focusChanged,
            .selectionChanged,
            .selectionUnavailable,
            .replacementUnsupported
        ]

        for failure in failures {
            let context = makeContext()
            let clipboard = SelectionTestClipboard()
            let provider = MockActiveTextContextProvider(
                captureResult: .available(context),
                replacementAttempt: .rejected(failure)
            )
            let service = makeService(clipboard: clipboard, provider: provider)

            let result = try service.deliver(
                "安全降级结果",
                replacing: context,
                replaceAutomatically: true
            )

            XCTAssertEqual(result, .copiedFallback(failure))
            XCTAssertEqual(clipboard.string, "安全降级结果")
            XCTAssertEqual(provider.replacementRequests.count, 1)
        }
    }

    func testAutomaticReplacementDisabledCopiesWithoutValidation() throws {
        let context = makeContext()
        let clipboard = SelectionTestClipboard()
        let provider = MockActiveTextContextProvider(
            captureResult: .available(context),
            replacementAttempt: .replaced
        )
        let service = makeService(clipboard: clipboard, provider: provider)

        let result = try service.deliver(
            "只复制",
            replacing: context,
            replaceAutomatically: false
        )

        XCTAssertEqual(result, .copiedFallback(.automaticReplacementDisabled))
        XCTAssertEqual(clipboard.string, "只复制")
        XCTAssertTrue(provider.replacementRequests.isEmpty)
    }

    func testOversizedAndUnavailableCaptureRemainExplicit() {
        let oversizedProvider = MockActiveTextContextProvider(captureResult: .tooLong(characterCount: 8_001))
        let unavailableProvider = MockActiveTextContextProvider(
            captureResult: .unavailable(.focusedElementUnavailable)
        )

        XCTAssertEqual(
            makeService(provider: oversizedProvider).captureActiveTextContext(maximumCharacterCount: 8_000),
            .tooLong(characterCount: 8_001)
        )
        XCTAssertEqual(
            makeService(provider: unavailableProvider).captureActiveTextContext(maximumCharacterCount: 8_000),
            .unavailable(.focusedElementUnavailable)
        )
    }

    func testEmptyReplacementIsRejectedBeforeValidationOrClipboardWrite() {
        let context = makeContext()
        let clipboard = SelectionTestClipboard()
        let provider = MockActiveTextContextProvider(captureResult: .available(context))
        let service = makeService(clipboard: clipboard, provider: provider)

        XCTAssertThrowsError(
            try service.deliver("  ", replacing: context, replaceAutomatically: true)
        ) { error in
            XCTAssertEqual(error as? ReadyTypeError, .pasteFailed)
        }
        XCTAssertNil(clipboard.string)
        XCTAssertTrue(provider.replacementRequests.isEmpty)
    }

    func testFingerprintValidationP95StaysUnderFiftyMilliseconds() {
        let captured = makeContext(text: String(repeating: "中英 mixed text ", count: 200)).fingerprint
        let current = makeContext(text: String(repeating: "中英 mixed text ", count: 200)).fingerprint
        var samples: [Double] = []

        for _ in 0..<500 {
            let started = DispatchTime.now().uptimeNanoseconds
            _ = captured.validationFailure(comparedTo: current)
            samples.append(Double(DispatchTime.now().uptimeNanoseconds - started) / 1_000_000)
        }

        let sorted = samples.sorted()
        let p95 = sorted[Int(ceil(Double(sorted.count) * 0.95)) - 1]
        print(String(format: "Selection fingerprint benchmark: samples=%d p95=%.3fms", samples.count, p95))
        XCTAssertLessThan(p95, 50)
    }

    private func makeContext(
        processIdentifier: Int32 = 10,
        elementIdentifier: String = "editor",
        text: String = "原文",
        range: TextSelectionRange = TextSelectionRange(location: 2, length: 2)
    ) -> ActiveTextContext {
        let target = SelectionTargetReference(
            processIdentifier: processIdentifier,
            testIdentifier: elementIdentifier
        )
        return ActiveTextContext(
            selectedText: text,
            fingerprint: SelectionFingerprint(target: target, range: range, selectedText: text)
        )
    }

    private func makeService(
        clipboard: SelectionTestClipboard = SelectionTestClipboard(),
        provider: MockActiveTextContextProvider
    ) -> PasteService {
        PasteService(
            clipboard: clipboard,
            directTextInserter: SelectionTestDirectInserter(),
            pasteInvoker: SelectionTestPasteInvoker(),
            pasteTargetActivator: SelectionTestTargetActivator(),
            activeTextContextProvider: provider
        )
    }
}

@MainActor
private final class MockActiveTextContextProvider: ActiveTextContextProviding {
    struct ReplacementRequest {
        let text: String
        let context: ActiveTextContext
    }

    private let captureResult: ActiveTextContextCaptureResult
    private let replacementAttempt: SelectionReplacementAttempt
    private(set) var captureLimits: [Int] = []
    private(set) var replacementRequests: [ReplacementRequest] = []

    init(
        captureResult: ActiveTextContextCaptureResult,
        replacementAttempt: SelectionReplacementAttempt = .rejected(.selectionUnavailable)
    ) {
        self.captureResult = captureResult
        self.replacementAttempt = replacementAttempt
    }

    func capture(maximumCharacterCount: Int) -> ActiveTextContextCaptureResult {
        captureLimits.append(maximumCharacterCount)
        return captureResult
    }

    func replaceSelectedText(_ text: String, ifMatching context: ActiveTextContext) -> SelectionReplacementAttempt {
        replacementRequests.append(ReplacementRequest(text: text, context: context))
        return replacementAttempt
    }
}

private final class SelectionTestClipboard: ClipboardWriting {
    private(set) var string: String?

    func writeString(_ string: String) throws {
        self.string = string
    }
}

private final class SelectionTestDirectInserter: DirectTextInserting {
    func insert(_ text: String) -> Bool { false }
}

private final class SelectionTestPasteInvoker: PasteInvoking {
    func invokePaste() -> Bool { false }
}

@MainActor
private final class SelectionTestTargetActivator: PasteTargetActivating {
    func captureCurrentTarget() {}
    func prepareForPaste() -> Bool { false }
}
