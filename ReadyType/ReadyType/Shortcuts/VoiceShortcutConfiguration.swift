import Foundation

struct VoiceShortcutConfiguration: Codable, Equatable {
    var trigger: VoiceShortcutTrigger
    var doublePressInterval: TimeInterval

    init(trigger: VoiceShortcutTrigger, doublePressInterval: TimeInterval = 0.45) {
        self.trigger = trigger
        self.doublePressInterval = doublePressInterval
    }

    static let `default` = VoiceShortcutConfiguration(trigger: .doubleOption)

    var displayName: String {
        trigger.displayName
    }
}

enum VoiceShortcutTrigger: String, Codable, CaseIterable, Identifiable {
    case doubleOption
    case doubleControl
    case doubleCommand
    case doubleFunction

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .doubleOption:
            return "双击 Option"
        case .doubleControl:
            return "双击 Control"
        case .doubleCommand:
            return "双击 Command"
        case .doubleFunction:
            return "双击 Fn"
        }
    }

    var shortDisplayName: String {
        switch self {
        case .doubleOption:
            return "Option x2"
        case .doubleControl:
            return "Control x2"
        case .doubleCommand:
            return "Command x2"
        case .doubleFunction:
            return "Fn x2"
        }
    }

    var modifierChord: ModifierChord {
        switch self {
        case .doubleOption:
            return .option
        case .doubleControl:
            return .control
        case .doubleCommand:
            return .command
        case .doubleFunction:
            return .fn
        }
    }
}
