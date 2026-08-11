import Foundation

struct OutputContext: Equatable {
    let scenario: OutputScenario
    let chatTone: ChatTone

    init(scenario: OutputScenario, chatTone: ChatTone = .default) {
        self.scenario = scenario
        self.chatTone = scenario == .message ? chatTone : .default
    }

    static func infer(bundleIdentifier: String?, windowTitle: String?, transcript: String? = nil) -> OutputContext {
        let decision = ContextEngine().resolve(
            ContextRequest(
                bundleIdentifier: bundleIdentifier,
                windowTitle: windowTitle,
                transcript: transcript
            )
        )
        return OutputContext(
            scenario: decision.scenario,
            chatTone: decision.chatTone
        )
    }
}

enum ChatTone: Equatable {
    case `default`
    case personal
    case work

    static func infer(bundleIdentifier: String?, windowTitle: String?) -> ChatTone {
        AppProfileCatalog().chatTone(bundleIdentifier: bundleIdentifier, windowTitle: windowTitle)
    }
}
