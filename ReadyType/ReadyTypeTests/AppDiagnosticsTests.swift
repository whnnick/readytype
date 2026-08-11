import XCTest
@testable import ReadyType

final class AppDiagnosticsTests: XCTestCase {
    func testDebugInsertIsDisabledByDefault() {
        XCTAssertFalse(AppDiagnostics.isDebugInsertEnabled(environment: [:]))
    }

    func testDebugInsertRequiresExplicitEnvironmentOptIn() {
        XCTAssertTrue(AppDiagnostics.isDebugInsertEnabled(environment: [
            AppDiagnostics.debugInsertEnvironmentKey: "1"
        ]))

        XCTAssertFalse(AppDiagnostics.isDebugInsertEnabled(environment: [
            AppDiagnostics.debugInsertEnvironmentKey: "true"
        ]))
    }

    func testDebugSelectionIsDisabledByDefault() {
        XCTAssertFalse(AppDiagnostics.isDebugSelectionEnabled(environment: [:]))
    }

    func testDebugSelectionRequiresExplicitEnvironmentOptIn() {
        XCTAssertTrue(AppDiagnostics.isDebugSelectionEnabled(environment: [
            AppDiagnostics.debugSelectionEnvironmentKey: "1"
        ]))
        XCTAssertFalse(AppDiagnostics.isDebugSelectionEnabled(environment: [
            AppDiagnostics.debugSelectionEnvironmentKey: "true"
        ]))
    }

    func testDebugSelectionResultPathIsRestrictedToNamedTemporaryFile() {
        XCTAssertTrue(AppDiagnostics.isValidDebugSelectionResultPath(
            "/private/tmp/readytype-selection-result-123"
        ))
        XCTAssertTrue(AppDiagnostics.isValidDebugSelectionResultPath(
            "/tmp/readytype-selection-result-123"
        ))
        XCTAssertFalse(AppDiagnostics.isValidDebugSelectionResultPath(
            "/private/tmp/readytype-selection-result-/../../../etc/readytype-result"
        ))
        XCTAssertFalse(AppDiagnostics.isValidDebugSelectionResultPath(
            "/private/tmp/unrelated-result"
        ))
    }

    func testDebugHUDIsDisabledByDefault() {
        XCTAssertFalse(AppDiagnostics.isDebugHUDEnabled(environment: [:]))
    }

    func testDebugHUDRequiresExplicitEnvironmentOptIn() {
        XCTAssertTrue(AppDiagnostics.isDebugHUDEnabled(environment: [
            AppDiagnostics.debugHUDEnvironmentKey: "1"
        ]))

        XCTAssertFalse(AppDiagnostics.isDebugHUDEnabled(environment: [
            AppDiagnostics.debugHUDEnvironmentKey: "true"
        ]))
    }

    func testDebugVocabularyIsDisabledByDefault() {
        XCTAssertFalse(AppDiagnostics.isDebugVocabularyEnabled(environment: [:]))
    }

    func testDebugVocabularyRequiresExplicitEnvironmentOptIn() {
        XCTAssertTrue(AppDiagnostics.isDebugVocabularyEnabled(environment: [
            AppDiagnostics.debugVocabularyEnvironmentKey: "1"
        ]))

        XCTAssertFalse(AppDiagnostics.isDebugVocabularyEnabled(environment: [
            AppDiagnostics.debugVocabularyEnvironmentKey: "true"
        ]))
    }

    func testDebugVocabularyFileAndValueRequireOptIn() {
        let environment = [
            AppDiagnostics.debugVocabularyFileEnvironmentKey: "/tmp/readytype-vocabulary.json",
            AppDiagnostics.debugVocabularyValueEnvironmentKey: " ReadyType Test "
        ]

        XCTAssertNil(AppDiagnostics.debugVocabularyFileURL(environment: environment))
        XCTAssertNil(AppDiagnostics.debugVocabularyValue(environment: environment))
    }

    func testDebugVocabularyFileAndValueUseExplicitDiagnosticEnvironment() {
        let environment = [
            AppDiagnostics.debugVocabularyEnvironmentKey: "1",
            AppDiagnostics.debugVocabularyFileEnvironmentKey: "/tmp/readytype-vocabulary.json",
            AppDiagnostics.debugVocabularyValueEnvironmentKey: " ReadyType Test "
        ]

        XCTAssertEqual(
            AppDiagnostics.debugVocabularyFileURL(environment: environment)?.path,
            "/tmp/readytype-vocabulary.json"
        )
        XCTAssertEqual(AppDiagnostics.debugVocabularyValue(environment: environment), "ReadyType Test")
    }

    func testLaunchWindowSuppressionIsDisabledByDefault() {
        XCTAssertFalse(AppDiagnostics.shouldSuppressLaunchWindow(environment: [:]))
    }

    func testLaunchWindowSuppressionRequiresExplicitEnvironmentOptIn() {
        XCTAssertTrue(AppDiagnostics.shouldSuppressLaunchWindow(environment: [
            AppDiagnostics.suppressLaunchWindowEnvironmentKey: "1"
        ]))

        XCTAssertFalse(AppDiagnostics.shouldSuppressLaunchWindow(environment: [
            AppDiagnostics.suppressLaunchWindowEnvironmentKey: "true"
        ]))
    }
}
