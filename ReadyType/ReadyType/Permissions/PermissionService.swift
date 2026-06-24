import AppKit
import AVFoundation
import Foundation
import Speech

enum PermissionStatus: Equatable {
    case granted
    case denied
    case restricted
    case notDetermined

    var isGranted: Bool {
        self == .granted
    }
}

struct PermissionSnapshot: Equatable {
    let microphone: PermissionStatus
    let speechRecognition: PermissionStatus
    let accessibility: PermissionStatus

    var canRecord: Bool {
        microphone.isGranted
    }

    var canTranscribe: Bool {
        speechRecognition.isGranted
    }

    var canPasteAutomatically: Bool {
        accessibility.isGranted
    }

    var isFullyReady: Bool {
        canRecord && canTranscribe && canPasteAutomatically
    }

    var blockingErrors: [ReadyTypeError] {
        var errors: [ReadyTypeError] = []

        if !canRecord {
            errors.append(.microphonePermissionMissing)
        }

        if !canTranscribe {
            errors.append(.speechRecognitionPermissionMissing)
        }

        if !canPasteAutomatically {
            errors.append(.accessibilityPermissionMissing)
        }

        return errors
    }
}

@MainActor
final class PermissionService {
    private let microphoneStatus: @MainActor () -> PermissionStatus
    private let speechRecognitionStatus: @MainActor () -> PermissionStatus
    private let accessibilityStatus: @MainActor () -> PermissionStatus
    private let requestMicrophonePermission: @MainActor () async -> PermissionStatus
    private let requestSpeechRecognitionPermission: @MainActor () async -> PermissionStatus

    init(
        microphoneStatus: @escaping @MainActor () -> PermissionStatus = PermissionService.currentMicrophoneStatus,
        speechRecognitionStatus: @escaping @MainActor () -> PermissionStatus = PermissionService.currentSpeechRecognitionStatus,
        accessibilityStatus: @escaping @MainActor () -> PermissionStatus = PermissionService.currentAccessibilityStatus,
        requestMicrophonePermission: @escaping @MainActor () async -> PermissionStatus = PermissionService.requestCurrentMicrophonePermission,
        requestSpeechRecognitionPermission: @escaping @MainActor () async -> PermissionStatus = PermissionService.requestCurrentSpeechRecognitionPermission
    ) {
        self.microphoneStatus = microphoneStatus
        self.speechRecognitionStatus = speechRecognitionStatus
        self.accessibilityStatus = accessibilityStatus
        self.requestMicrophonePermission = requestMicrophonePermission
        self.requestSpeechRecognitionPermission = requestSpeechRecognitionPermission
    }

    func snapshot() -> PermissionSnapshot {
        PermissionSnapshot(
            microphone: microphoneStatus(),
            speechRecognition: speechRecognitionStatus(),
            accessibility: accessibilityStatus()
        )
    }

    func requestCorePermissions() async -> PermissionSnapshot {
        var microphone = microphoneStatus()
        var speechRecognition = speechRecognitionStatus()

        if microphone == .notDetermined {
            microphone = await requestMicrophonePermission()
        }

        if speechRecognition == .notDetermined {
            speechRecognition = await requestSpeechRecognitionPermission()
        }

        return PermissionSnapshot(
            microphone: microphone,
            speechRecognition: speechRecognition,
            accessibility: accessibilityStatus()
        )
    }

    static func currentMicrophoneStatus() -> PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return .granted
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .denied
        }
    }

    static func currentSpeechRecognitionStatus() -> PermissionStatus {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return .granted
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .denied
        }
    }

    static func currentAccessibilityStatus() -> PermissionStatus {
        AXIsProcessTrusted() ? .granted : .denied
    }

    static func promptForAccessibilityPermission() -> PermissionStatus {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options) ? .granted : .denied
    }

    nonisolated static func requestCurrentMicrophonePermission() async -> PermissionStatus {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { isGranted in
                continuation.resume(returning: isGranted ? .granted : .denied)
            }
        }
    }

    nonisolated static func requestCurrentSpeechRecognitionPermission() async -> PermissionStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: permissionStatus(for: status))
            }
        }
    }

    nonisolated private static func permissionStatus(for status: SFSpeechRecognizerAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .authorized:
            return .granted
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .denied
        }
    }
}
