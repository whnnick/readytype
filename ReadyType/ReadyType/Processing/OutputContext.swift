import Foundation

struct OutputContext: Equatable {
    let scenario: OutputScenario
    let chatTone: ChatTone

    init(scenario: OutputScenario, chatTone: ChatTone = .default) {
        self.scenario = scenario
        self.chatTone = scenario == .message ? chatTone : .default
    }

    static func infer(bundleIdentifier: String?, windowTitle: String?, transcript: String? = nil) -> OutputContext {
        let scenario = OutputScenario.infer(
            bundleIdentifier: bundleIdentifier,
            windowTitle: windowTitle,
            transcript: transcript
        )
        return OutputContext(
            scenario: scenario,
            chatTone: ChatTone.infer(bundleIdentifier: bundleIdentifier, windowTitle: windowTitle)
        )
    }
}

enum ChatTone: Equatable {
    case `default`
    case personal
    case work

    static func infer(bundleIdentifier: String?, windowTitle: String?) -> ChatTone {
        let bundle = (bundleIdentifier ?? "").lowercased()
        let title = (windowTitle ?? "").lowercased()

        if bundle.contains("wechat") ||
            bundle.contains("xinwechat") ||
            bundle.contains("qq") ||
            bundle.contains("telegram") ||
            bundle.contains("whatsapp") ||
            bundle.contains("messages") ||
            title.contains("微信") {
            return .personal
        }

        if bundle.contains("feishu") ||
            bundle.contains("larksuite") ||
            bundle.contains("slack") ||
            bundle.contains("teams") ||
            bundle.contains("discord") {
            return .work
        }

        return .default
    }
}
