import XCTest
@testable import ReadyType

@MainActor
final class PermissionServiceTests: XCTestCase {
    func testPermissionSnapshotReportsReadyWhenAllPermissionsGranted() {
        let service = PermissionService(
            microphoneStatus: { .granted },
            speechRecognitionStatus: { .granted },
            accessibilityStatus: { .granted }
        )

        let snapshot = service.snapshot()

        XCTAssertTrue(snapshot.canRecord)
        XCTAssertTrue(snapshot.canTranscribe)
        XCTAssertTrue(snapshot.canPasteAutomatically)
        XCTAssertTrue(snapshot.isFullyReady)
        XCTAssertTrue(snapshot.blockingErrors.isEmpty)
    }

    func testPermissionSnapshotBlocksRecordingWhenMicrophoneMissing() {
        let service = PermissionService(
            microphoneStatus: { .denied },
            speechRecognitionStatus: { .granted },
            accessibilityStatus: { .granted }
        )

        let snapshot = service.snapshot()

        XCTAssertFalse(snapshot.canRecord)
        XCTAssertTrue(snapshot.canTranscribe)
        XCTAssertTrue(snapshot.canPasteAutomatically)
        XCTAssertFalse(snapshot.isFullyReady)
        XCTAssertEqual(snapshot.blockingErrors, [.microphonePermissionMissing])
    }

    func testPermissionSnapshotTreatsMissingAccessibilityAsPasteFallbackOnly() {
        let service = PermissionService(
            microphoneStatus: { .granted },
            speechRecognitionStatus: { .granted },
            accessibilityStatus: { .denied }
        )

        let snapshot = service.snapshot()

        XCTAssertTrue(snapshot.canRecord)
        XCTAssertTrue(snapshot.canTranscribe)
        XCTAssertFalse(snapshot.canPasteAutomatically)
        XCTAssertFalse(snapshot.isFullyReady)
        XCTAssertEqual(snapshot.blockingErrors, [.accessibilityPermissionMissing])
    }

    func testPermissionSnapshotReportsSpeechMissing() {
        let service = PermissionService(
            microphoneStatus: { .granted },
            speechRecognitionStatus: { .notDetermined },
            accessibilityStatus: { .granted }
        )

        let snapshot = service.snapshot()

        XCTAssertTrue(snapshot.canRecord)
        XCTAssertFalse(snapshot.canTranscribe)
        XCTAssertTrue(snapshot.canPasteAutomatically)
        XCTAssertEqual(snapshot.blockingErrors, [.speechRecognitionPermissionMissing])
    }

    func testRequestCorePermissionsRequestsOnlyUndeterminedStatuses() async {
        var microphoneRequestCount = 0
        var speechRequestCount = 0
        let service = PermissionService(
            microphoneStatus: { .notDetermined },
            speechRecognitionStatus: { .granted },
            accessibilityStatus: { .denied },
            requestMicrophonePermission: {
                microphoneRequestCount += 1
                return .granted
            },
            requestSpeechRecognitionPermission: {
                speechRequestCount += 1
                return .granted
            }
        )

        let snapshot = await service.requestCorePermissions()

        XCTAssertEqual(microphoneRequestCount, 1)
        XCTAssertEqual(speechRequestCount, 0)
        XCTAssertEqual(snapshot.microphone, .granted)
        XCTAssertEqual(snapshot.speechRecognition, .granted)
        XCTAssertEqual(snapshot.accessibility, .denied)
    }

    func testRequestCorePermissionsKeepsDeniedResult() async {
        let service = PermissionService(
            microphoneStatus: { .notDetermined },
            speechRecognitionStatus: { .notDetermined },
            accessibilityStatus: { .granted },
            requestMicrophonePermission: { .denied },
            requestSpeechRecognitionPermission: { .granted }
        )

        let snapshot = await service.requestCorePermissions()

        XCTAssertEqual(snapshot.microphone, .denied)
        XCTAssertEqual(snapshot.speechRecognition, .granted)
        XCTAssertFalse(snapshot.canRecord)
        XCTAssertTrue(snapshot.canTranscribe)
    }
}
