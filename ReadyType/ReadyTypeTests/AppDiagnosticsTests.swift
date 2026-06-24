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
