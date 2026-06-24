import Foundation

enum AppDiagnostics {
    static let debugInsertEnvironmentKey = "READYTYPE_ENABLE_DEBUG_INSERT"
    static let debugHUDEnvironmentKey = "READYTYPE_ENABLE_DEBUG_HUD"
    static let debugVocabularyEnvironmentKey = "READYTYPE_ENABLE_DEBUG_VOCABULARY"
    static let suppressLaunchWindowEnvironmentKey = "READYTYPE_SUPPRESS_LAUNCH_WINDOW"

    static func isDebugInsertEnabled(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        environment[debugInsertEnvironmentKey] == "1"
    }

    static func isDebugHUDEnabled(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        environment[debugHUDEnvironmentKey] == "1"
    }

    static func isDebugVocabularyEnabled(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        environment[debugVocabularyEnvironmentKey] == "1"
    }

    static func shouldSuppressLaunchWindow(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        environment[suppressLaunchWindowEnvironmentKey] == "1"
    }
}
