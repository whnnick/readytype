import AppKit
import SwiftUI

struct MotionPreferences: Equatable {
    let reduceMotion: Bool

    static var current: MotionPreferences {
        MotionPreferences(reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
    }
}

enum MotionTokens {
    static let voiceCapsuleCornerRadius: CGFloat = 28
    static let voiceCapsuleHeight: CGFloat = 74

    static func hudEntranceOffset(for preferences: MotionPreferences = .current) -> CGFloat {
        preferences.reduceMotion ? 0 : 12
    }

    static func waveAnimationEnabled(for preferences: MotionPreferences = .current) -> Bool {
        !preferences.reduceMotion
    }

    static func errorShakeEnabled(for preferences: MotionPreferences = .current) -> Bool {
        !preferences.reduceMotion
    }

    static func voiceCapsuleFlowEnabled(
        for state: RuntimeState,
        preferences: MotionPreferences = .current
    ) -> Bool {
        guard !preferences.reduceMotion else {
            return false
        }

        switch state {
        case .idle, .error:
            return false
        case .recording, .transcribing, .processingAI, .pasted, .copiedFallback:
            return true
        }
    }

    static func voiceCapsuleFlowDuration(for state: RuntimeState) -> Double {
        switch state {
        case .recording:
            return 1.55
        case .transcribing:
            return 2.05
        case .processingAI:
            return 2.35
        case .pasted:
            return 0.92
        case .copiedFallback:
            return 1.18
        case .idle, .error:
            return 1.7
        }
    }

    static func voiceCapsuleFlowOpacity(
        for state: RuntimeState,
        preferences: MotionPreferences = .current
    ) -> Double {
        guard voiceCapsuleFlowEnabled(for: state, preferences: preferences) else {
            return 0
        }

        switch state {
        case .recording:
            return 0.90
        case .transcribing:
            return 0.64
        case .processingAI:
            return 0.52
        case .pasted:
            return 0.76
        case .copiedFallback:
            return 0.46
        case .idle, .error:
            return 0
        }
    }

    static func voiceCapsuleGlowOpacity(
        for state: RuntimeState,
        preferences: MotionPreferences = .current
    ) -> Double {
        guard !preferences.reduceMotion else {
            return 0.06
        }

        switch state {
        case .recording:
            return 0.24
        case .transcribing:
            return 0.17
        case .processingAI:
            return 0.14
        case .pasted:
            return 0.22
        case .copiedFallback:
            return 0.16
        case .error:
            return 0.14
        case .idle:
            return 0.08
        }
    }

    static func voiceCapsuleScale(
        for state: RuntimeState,
        preferences: MotionPreferences = .current
    ) -> CGFloat {
        guard !preferences.reduceMotion else {
            return 1
        }

        switch state {
        case .pasted:
            return 1.018
        default:
            return 1
        }
    }

    static func voiceCapsuleErrorPulseEnabled(
        for state: RuntimeState,
        preferences: MotionPreferences = .current
    ) -> Bool {
        guard !preferences.reduceMotion else {
            return false
        }

        if case .error = state {
            return true
        }

        return false
    }

    static func statusAnimation(for preferences: MotionPreferences = .current) -> Animation {
        preferences.reduceMotion ? .easeInOut(duration: 0.14) : .spring(response: 0.26, dampingFraction: 0.86)
    }

    static func crossfadeAnimation(for preferences: MotionPreferences = .current) -> Animation {
        .easeInOut(duration: preferences.reduceMotion ? 0.12 : 0.16)
    }

    static func popoverSelectionAnimation(for preferences: MotionPreferences = .current) -> Animation {
        preferences.reduceMotion ? .easeInOut(duration: 0.12) : .spring(response: 0.22, dampingFraction: 0.88)
    }
}
