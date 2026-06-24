import Foundation

struct SpeechRecognitionRouteContext: Equatable {
    var mode: SpeechRecognitionMode
    var scenario: OutputScenario
    var frontmostAppBundleIdentifier: String?
    var recordingDuration: TimeInterval
    var hasLowConfidenceSignal: Bool
    var hasChineseMisclassifiedAsEnglishSignal: Bool
    var isLowPowerModeEnabled: Bool
    var localModelState: LocalSpeechModelState
    var contextualTerms: [String]
}

struct SpeechRecognitionRouteDecision: Equatable {
    var backend: SpeechRecognitionBackendSelection
    var fallbackReason: String?
}

enum SpeechRecognitionBackendSelection: Equatable {
    case fastSystem
    case highAccuracyLocal
}

struct SpeechRecognitionRouter {
    func route(context: SpeechRecognitionRouteContext) -> SpeechRecognitionRouteDecision {
        switch context.mode {
        case .fastSystem:
            return SpeechRecognitionRouteDecision(backend: .fastSystem, fallbackReason: nil)
        case .highAccuracyLocal:
            return highAccuracyDecision(context: context)
        case .automatic:
            return automaticDecision(context: context)
        }
    }

    private func highAccuracyDecision(context: SpeechRecognitionRouteContext) -> SpeechRecognitionRouteDecision {
        guard context.localModelState.isReadyForRecognition else {
            return SpeechRecognitionRouteDecision(
                backend: .fastSystem,
                fallbackReason: "高精度识别未就绪，已使用极速识别。"
            )
        }

        return SpeechRecognitionRouteDecision(backend: .highAccuracyLocal, fallbackReason: nil)
    }

    private func automaticDecision(context: SpeechRecognitionRouteContext) -> SpeechRecognitionRouteDecision {
        guard context.shouldPreferHighAccuracy else {
            return SpeechRecognitionRouteDecision(backend: .fastSystem, fallbackReason: nil)
        }

        guard !context.isLowPowerModeEnabled else {
            return SpeechRecognitionRouteDecision(
                backend: .fastSystem,
                fallbackReason: "低电量模式下已使用极速识别。"
            )
        }

        guard context.localModelState.isReadyForAutomaticRecognition else {
            return SpeechRecognitionRouteDecision(
                backend: .fastSystem,
                fallbackReason: context.localModelState.automaticFallbackReason
            )
        }

        return SpeechRecognitionRouteDecision(backend: .highAccuracyLocal, fallbackReason: nil)
    }
}

private extension SpeechRecognitionRouteContext {
    var shouldPreferHighAccuracy: Bool {
        if hasChineseMisclassifiedAsEnglishSignal || hasLowConfidenceSignal {
            return true
        }

        if recordingDuration >= 12 {
            return true
        }

        switch scenario {
        case .email, .aiTool, .document:
            return isTechnicalApp
        case .note:
            return recordingDuration >= 8 || !contextualTerms.isEmpty
        case .generic:
            return isTechnicalApp
        case .message:
            return false
        }
    }

    var isTechnicalApp: Bool {
        let bundle = (frontmostAppBundleIdentifier ?? "").lowercased()
        return bundle.contains("cursor") ||
            bundle.contains("xcode") ||
            bundle.contains("terminal") ||
            bundle.contains("iterm") ||
            bundle.contains("obsidian") ||
            bundle.contains("codex") ||
            bundle.contains("todesktop")
    }
}

private extension LocalSpeechModelState {
    var isReadyForRecognition: Bool {
        switch self {
        case .downloadedCold, .warm:
            return true
        case .notInstalled, .downloading, .warming, .failed:
            return false
        }
    }

    var isReadyForAutomaticRecognition: Bool {
        self == .warm
    }

    var automaticFallbackReason: String {
        switch self {
        case .downloadedCold, .warming:
            return "高精度识别正在准备，已使用极速识别。"
        case .notInstalled, .downloading, .failed, .warm:
            return "高精度识别未就绪，已使用极速识别。"
        }
    }
}
