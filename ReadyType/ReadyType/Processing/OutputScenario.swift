import AppKit
import Foundation

enum OutputScenario: String, CaseIterable, Identifiable, Equatable {
    case generic
    case email
    case message
    case note
    case aiTool
    case document

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .generic:
            return "通用"
        case .email:
            return "邮件"
        case .message:
            return "聊天"
        case .aiTool:
            return "AI 工具"
        case .note:
            return "笔记"
        case .document:
            return "文档"
        }
    }

    var userDescription: String {
        switch self {
        case .generic:
            return "不确定输入环境时使用，输出清楚自然，不强行套格式。"
        case .email:
            return "适合邮件正文，默认整理为问候、正文和礼貌收尾。"
        case .message:
            return "适合聊天工具，保持简短自然，不写成报告。"
        case .aiTool:
            return "适合发给 AI 工具，整理为任务、背景、约束和输出要求。"
        case .note:
            return "适合笔记软件，整理为标题、要点和待办。"
        case .document:
            return "适合长文档、说明和方案，使用更正式的段落结构。"
        }
    }

    static func infer(bundleIdentifier: String?, windowTitle: String?, transcript: String? = nil) -> OutputScenario {
        ContextEngine().resolve(
            ContextRequest(
                bundleIdentifier: bundleIdentifier,
                windowTitle: windowTitle,
                transcript: transcript
            )
        ).scenario
    }
}

enum OutputScenarioSelection: String, CaseIterable, Identifiable, Equatable {
    case automatic
    case generic
    case email
    case message
    case note
    case aiTool
    case document

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .automatic:
            return "自动"
        case .generic:
            return OutputScenario.generic.displayName
        case .email:
            return OutputScenario.email.displayName
        case .message:
            return OutputScenario.message.displayName
        case .aiTool:
            return OutputScenario.aiTool.displayName
        case .note:
            return OutputScenario.note.displayName
        case .document:
            return OutputScenario.document.displayName
        }
    }

    var userDescription: String {
        switch self {
        case .automatic:
            return "根据前台 App 和窗口标题自动判断；判断不准时可手动选择。"
        case .generic:
            return OutputScenario.generic.userDescription
        case .email:
            return OutputScenario.email.userDescription
        case .message:
            return OutputScenario.message.userDescription
        case .aiTool:
            return OutputScenario.aiTool.userDescription
        case .note:
            return OutputScenario.note.userDescription
        case .document:
            return OutputScenario.document.userDescription
        }
    }

    var manualScenario: OutputScenario? {
        switch self {
        case .automatic:
            return nil
        case .generic:
            return .generic
        case .email:
            return .email
        case .message:
            return .message
        case .aiTool:
            return .aiTool
        case .note:
            return .note
        case .document:
            return .document
        }
    }

    func compactSummary(for mode: OutputMode) -> String? {
        guard mode.requiresAI else {
            return nil
        }

        return "场景：\(displayName)"
    }

    func hudLabel(for mode: OutputMode) -> String? {
        guard mode.requiresAI else {
            return nil
        }

        return displayName
    }
}

struct ForegroundContext: Equatable {
    let bundleIdentifier: String?
    let localizedName: String?
    let windowTitle: String?

    var inferredScenario: OutputScenario {
        OutputScenario.infer(bundleIdentifier: bundleIdentifier, windowTitle: windowTitle)
    }
}

@MainActor
final class ForegroundContextService {
    func currentContext() -> ForegroundContext {
        let application = NSWorkspace.shared.frontmostApplication
        return ForegroundContext(
            bundleIdentifier: application?.bundleIdentifier,
            localizedName: application?.localizedName,
            windowTitle: Self.windowTitle(for: application)
        )
    }

    private static func windowTitle(for application: NSRunningApplication?) -> String? {
        guard let processIdentifier = application?.processIdentifier else {
            return nil
        }

        let appElement = AXUIElementCreateApplication(processIdentifier)
        var focusedWindow: CFTypeRef?
        let focusedWindowResult = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindow
        )

        let windowElement: AXUIElement
        if focusedWindowResult == .success, let focusedWindow {
            windowElement = focusedWindow as! AXUIElement
        } else {
            var mainWindow: CFTypeRef?
            let mainWindowResult = AXUIElementCopyAttributeValue(
                appElement,
                kAXMainWindowAttribute as CFString,
                &mainWindow
            )
            guard mainWindowResult == .success, let mainWindow else {
                return nil
            }
            windowElement = mainWindow as! AXUIElement
        }

        var titleValue: CFTypeRef?
        let titleResult = AXUIElementCopyAttributeValue(
            windowElement,
            kAXTitleAttribute as CFString,
            &titleValue
        )

        guard titleResult == .success, let title = titleValue as? String, !title.isEmpty else {
            return nil
        }

        return title
    }
}
