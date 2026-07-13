import Foundation

@MainActor
protocol AnalyticsTracking: AnyObject {
    func track(_ event: ReadyTypeAnalyticsEvent)
}

@MainActor
final class NoopAnalyticsTracker: AnalyticsTracking {
    func track(_ event: ReadyTypeAnalyticsEvent) {}
}

@MainActor
final class ConsentAwareAnalyticsTracker: AnalyticsTracking {
    private let tracker: AnalyticsTracking
    private let isEnabled: () -> Bool

    init(tracker: AnalyticsTracking, isEnabled: @escaping () -> Bool) {
        self.tracker = tracker
        self.isEnabled = isEnabled
    }

    func track(_ event: ReadyTypeAnalyticsEvent) {
        guard isEnabled() else { return }
        tracker.track(event)
    }
}

enum ReadyTypeAnalyticsEvent: Equatable {
    case appLaunched(version: String, build: String, osMajorVersion: Int, architecture: AnalyticsArchitecture)
    case voiceInputStarted(recognitionSelection: AnalyticsRecognitionSelection, outputMethod: AnalyticsOutputMethod)
    case voiceInputFinished(
        engine: AnalyticsRecognitionEngine,
        outputMethod: AnalyticsOutputMethod,
        scenario: AnalyticsScenario,
        recordingDuration: AnalyticsDurationBucket,
        completionLatency: AnalyticsLatencyBucket,
        delivery: AnalyticsDelivery
    )
    case voiceInputCancelled(stage: AnalyticsVoiceStage)
    case voiceInputFailed(stage: AnalyticsVoiceStage, code: AnalyticsErrorCode)
}

enum AnalyticsArchitecture: String, Equatable {
    case arm64
    case x86_64
    case other

    static var current: Self {
#if arch(arm64)
        .arm64
#elseif arch(x86_64)
        .x86_64
#else
        .other
#endif
    }
}

enum AnalyticsRecognitionSelection: String, Equatable {
    case automatic
    case fast
    case accurate
}

enum AnalyticsRecognitionEngine: String, Equatable {
    case apple
    case local
}

enum AnalyticsOutputMethod: String, Equatable {
    case direct
    case polished
    case translate
    case ai
}

enum AnalyticsScenario: String, Equatable {
    case generic
    case chat
    case email
    case note
    case document
    case aiTool = "ai_tool"
}

enum AnalyticsDelivery: String, Equatable {
    case pasted
    case clipboard
    case failed
}

enum AnalyticsVoiceStage: String, Equatable {
    case permission
    case recording
    case transcription
    case processing
    case delivery
}

enum AnalyticsErrorCode: String, Equatable {
    case microphonePermission
    case speechRecognitionPermission
    case accessibilityPermission
    case keyboardMonitoringPermission
    case shortcutRegistration
    case recording
    case recordingTooShort
    case transcription
    case transcriptionEmpty
    case invalidSettings
    case apiKeyMissing
    case apiAuthentication
    case apiUnreachable
    case apiModel
    case apiRateLimited
    case apiUnavailable
    case apiTimeout
    case apiUnexpectedResponse
    case keychain
    case paste
}

enum AnalyticsDurationBucket: String, Equatable {
    case under5Seconds = "under_5s"
    case fiveTo15Seconds = "5_15s"
    case fifteenTo30Seconds = "15_30s"
    case over30Seconds = "over_30s"

    init(seconds: TimeInterval) {
        switch max(0, seconds) {
        case ..<5: self = .under5Seconds
        case ..<15: self = .fiveTo15Seconds
        case ..<30: self = .fifteenTo30Seconds
        default: self = .over30Seconds
        }
    }
}

enum AnalyticsLatencyBucket: String, Equatable {
    case under500Milliseconds = "under_500ms"
    case fiveHundredTo1500Milliseconds = "500_1500ms"
    case fifteenHundredTo3000Milliseconds = "1500_3000ms"
    case over3000Milliseconds = "over_3000ms"

    init(milliseconds: Int) {
        switch max(0, milliseconds) {
        case ..<500: self = .under500Milliseconds
        case ..<1_500: self = .fiveHundredTo1500Milliseconds
        case ..<3_000: self = .fifteenHundredTo3000Milliseconds
        default: self = .over3000Milliseconds
        }
    }
}

extension SpeechRecognitionMode {
    var analyticsValue: AnalyticsRecognitionSelection {
        switch self {
        case .automatic: .automatic
        case .fastSystem: .fast
        case .highAccuracyLocal: .accurate
        }
    }
}

extension SpeechRecognitionBackendSelection {
    var analyticsValue: AnalyticsRecognitionEngine {
        switch self {
        case .fastSystem: .apple
        case .highAccuracyLocal: .local
        }
    }
}

extension OutputMode {
    var analyticsValue: AnalyticsOutputMethod {
        switch self {
        case .dictation: .direct
        case .aiCleanup: .polished
        case .translationToEnglish: .translate
        case .promptOutput: .ai
        }
    }
}

extension OutputScenario {
    var analyticsValue: AnalyticsScenario {
        switch self {
        case .generic: .generic
        case .message: .chat
        case .email: .email
        case .note: .note
        case .document: .document
        case .aiTool: .aiTool
        }
    }
}

extension ReadyTypeError {
    var analyticsCode: AnalyticsErrorCode {
        switch self {
        case .microphonePermissionMissing: .microphonePermission
        case .speechRecognitionPermissionMissing: .speechRecognitionPermission
        case .accessibilityPermissionMissing: .accessibilityPermission
        case .keyboardMonitoringPermissionMissing: .keyboardMonitoringPermission
        case .shortcutRegistrationFailed: .shortcutRegistration
        case .recordingFailed: .recording
        case .recordingTooShort: .recordingTooShort
        case .transcriptionFailed: .transcription
        case .transcriptionEmpty: .transcriptionEmpty
        case .invalidSettings: .invalidSettings
        case .deepSeekAPIKeyMissing: .apiKeyMissing
        case .deepSeekAuthenticationFailed: .apiAuthentication
        case .deepSeekBaseURLUnreachable: .apiUnreachable
        case .deepSeekModelError: .apiModel
        case .deepSeekRateLimited: .apiRateLimited
        case .deepSeekServiceUnavailable: .apiUnavailable
        case .deepSeekTimeout: .apiTimeout
        case .deepSeekUnexpectedResponse: .apiUnexpectedResponse
        case .keychainOperationFailed: .keychain
        case .pasteFailed: .paste
        }
    }

    var analyticsStage: AnalyticsVoiceStage {
        switch self {
        case .microphonePermissionMissing, .speechRecognitionPermissionMissing,
             .accessibilityPermissionMissing, .keyboardMonitoringPermissionMissing:
            .permission
        case .shortcutRegistrationFailed, .recordingFailed, .recordingTooShort:
            .recording
        case .transcriptionFailed, .transcriptionEmpty:
            .transcription
        case .pasteFailed:
            .delivery
        case .invalidSettings, .deepSeekAPIKeyMissing, .deepSeekAuthenticationFailed,
             .deepSeekBaseURLUnreachable, .deepSeekModelError, .deepSeekRateLimited,
             .deepSeekServiceUnavailable, .deepSeekTimeout, .deepSeekUnexpectedResponse,
             .keychainOperationFailed:
            .processing
        }
    }
}
