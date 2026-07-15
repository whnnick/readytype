import Foundation

enum AppDiagnostics {
    static let debugInsertEnvironmentKey = "READYTYPE_ENABLE_DEBUG_INSERT"
    static let debugHUDEnvironmentKey = "READYTYPE_ENABLE_DEBUG_HUD"
    static let debugVocabularyEnvironmentKey = "READYTYPE_ENABLE_DEBUG_VOCABULARY"
    static let debugVocabularyFileEnvironmentKey = "READYTYPE_DEBUG_VOCABULARY_FILE"
    static let debugVocabularyValueEnvironmentKey = "READYTYPE_DEBUG_VOCABULARY_VALUE"
    static let suppressLaunchWindowEnvironmentKey = "READYTYPE_SUPPRESS_LAUNCH_WINDOW"
    static let visualAcceptanceDefaultsSuiteName = "com.readytype.visual-acceptance"

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

    static func debugVocabularyFileURL(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL? {
        guard isDebugVocabularyEnabled(environment: environment),
              let path = environment[debugVocabularyFileEnvironmentKey],
              path.hasPrefix("/")
        else {
            return nil
        }

        return URL(fileURLWithPath: path)
    }

    static func debugVocabularyValue(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> String? {
        guard isDebugVocabularyEnabled(environment: environment) else {
            return nil
        }

        let value = environment[debugVocabularyValueEnvironmentKey]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value : nil
    }

    static func shouldSuppressLaunchWindow(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        environment[suppressLaunchWindowEnvironmentKey] == "1"
    }
}
