import AppKit
import SwiftUI

struct MotionPreferences: Equatable {
    let reduceMotion: Bool

    static var current: MotionPreferences {
        MotionPreferences(reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
    }
}

enum MotionTokens {
    static let voiceCapsuleCornerRadius: CGFloat = 22
    static let voiceCapsuleWidth: CGFloat = 246
    static let voiceCapsuleHeight: CGFloat = 44
    static let voiceCapsuleWindowSize = NSSize(width: 420, height: 82)
    static let escapeHintDuration: TimeInterval = 1.6

    static func hudEntranceOffset(for preferences: MotionPreferences = .current) -> CGFloat {
        preferences.reduceMotion ? 0 : 12
    }

    static func waveAnimationEnabled(for preferences: MotionPreferences = .current) -> Bool {
        !preferences.reduceMotion
    }

    static func errorShakeEnabled(for preferences: MotionPreferences = .current) -> Bool {
        !preferences.reduceMotion
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
