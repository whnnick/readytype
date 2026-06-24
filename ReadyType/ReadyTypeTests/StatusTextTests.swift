import XCTest
@testable import ReadyType

final class StatusTextTests: XCTestCase {
    func testRuntimeStateUsesLastMessageWhenAvailable() {
        XCTAssertEqual(RuntimeState.recording.readyTypeDisplayMessage(lastMessage: "自定义状态"), "自定义状态")
    }

    func testRuntimeStateDefaultChineseMessages() {
        XCTAssertEqual(RuntimeState.idle.readyTypeDisplayMessage(), "准备就绪")
        XCTAssertEqual(RuntimeState.recording.readyTypeDisplayMessage(), "正在语音输入，再次双击 Option 完成，Esc 取消")
        XCTAssertEqual(RuntimeState.transcribing.readyTypeDisplayMessage(), "正在识别")
        XCTAssertEqual(RuntimeState.processingAI.readyTypeDisplayMessage(), "正在整理")
        XCTAssertEqual(RuntimeState.pasted.readyTypeDisplayMessage(), "已粘贴")
        XCTAssertEqual(RuntimeState.copiedFallback.readyTypeDisplayMessage(), "已复制到剪贴板")
        XCTAssertEqual(RuntimeState.error("麦克风未授权").readyTypeDisplayMessage(), "麦克风未授权")
    }

    func testRuntimeStateRecordingMessageUsesConfiguredShortcut() {
        let shortcut = VoiceShortcutConfiguration(trigger: .doubleControl)

        XCTAssertEqual(
            RuntimeState.recording.readyTypeDisplayMessage(shortcut: shortcut),
            "正在语音输入，再次双击 Control 完成，Esc 取消"
        )
    }

    func testVoiceInputHUDUsesInputFocusedCopy() {
        XCTAssertEqual(VoiceInputHUDText.presentation(for: .recording).title, "正在听你说话")
        XCTAssertEqual(VoiceInputHUDText.presentation(for: .recording).subtitle, "再次双击 Option 完成 · Esc 取消")
        XCTAssertEqual(VoiceInputHUDText.presentation(for: .transcribing).title, "正在识别")
        XCTAssertEqual(VoiceInputHUDText.presentation(for: .processingAI).title, "正在整理")
        XCTAssertEqual(VoiceInputHUDText.presentation(for: .pasted).title, "已输入")
        XCTAssertEqual(VoiceInputHUDText.presentation(for: .copiedFallback).title, "已复制到剪贴板")
    }

    func testVoiceInputHUDShowsReadableErrorDetail() {
        let presentation = VoiceInputHUDText.presentation(for: .error("需要麦克风权限才能语音输入。"))

        XCTAssertEqual(presentation.title, "这次没有完成")
        XCTAssertEqual(presentation.subtitle, "需要麦克风权限才能语音输入。")
    }

    func testRuntimeStateStatusRoles() {
        XCTAssertEqual(RuntimeState.idle.readyTypeStatusRole, .neutral)
        XCTAssertEqual(RuntimeState.recording.readyTypeStatusRole, .recording)
        XCTAssertEqual(RuntimeState.transcribing.readyTypeStatusRole, .progress)
        XCTAssertEqual(RuntimeState.processingAI.readyTypeStatusRole, .progress)
        XCTAssertEqual(RuntimeState.pasted.readyTypeStatusRole, .success)
        XCTAssertEqual(RuntimeState.copiedFallback.readyTypeStatusRole, .warning)
        XCTAssertEqual(RuntimeState.error("x").readyTypeStatusRole, .danger)
    }

    func testLocalSpeechModelStateChineseMessages() {
        XCTAssertEqual(LocalSpeechModelState.notInstalled.readyTypeDisplayMessage(isHighAccuracyEnabled: false), "高精度识别未启用")
        XCTAssertEqual(LocalSpeechModelState.notInstalled.readyTypeDisplayMessage(isHighAccuracyEnabled: true), "高精度语音包未安装")
        XCTAssertEqual(LocalSpeechModelState.downloading(progress: 0.42).readyTypeDisplayMessage(isHighAccuracyEnabled: true), "正在下载高精度语音包 42%")
        XCTAssertEqual(LocalSpeechModelState.downloadedCold.readyTypeDisplayMessage(isHighAccuracyEnabled: true), "高精度语音包已安装，尚未准备好")
        XCTAssertEqual(LocalSpeechModelState.warming.readyTypeDisplayMessage(isHighAccuracyEnabled: true), "正在准备高精度识别")
        XCTAssertEqual(LocalSpeechModelState.warm.readyTypeDisplayMessage(isHighAccuracyEnabled: true), "高精度识别已准备好")
        XCTAssertEqual(LocalSpeechModelState.failed(reason: "模型校验失败").readyTypeDisplayMessage(isHighAccuracyEnabled: true), "高精度识别暂不可用：模型校验失败")
    }

    func testLocalSpeechModelStateStatusRoles() {
        XCTAssertEqual(LocalSpeechModelState.notInstalled.readyTypeStatusRole(isHighAccuracyEnabled: false), .neutral)
        XCTAssertEqual(LocalSpeechModelState.notInstalled.readyTypeStatusRole(isHighAccuracyEnabled: true), .danger)
        XCTAssertEqual(LocalSpeechModelState.downloading(progress: 0.2).readyTypeStatusRole(isHighAccuracyEnabled: true), .progress)
        XCTAssertEqual(LocalSpeechModelState.downloadedCold.readyTypeStatusRole(isHighAccuracyEnabled: true), .warning)
        XCTAssertEqual(LocalSpeechModelState.warming.readyTypeStatusRole(isHighAccuracyEnabled: true), .progress)
        XCTAssertEqual(LocalSpeechModelState.warm.readyTypeStatusRole(isHighAccuracyEnabled: true), .success)
        XCTAssertEqual(LocalSpeechModelState.failed(reason: "x").readyTypeStatusRole(isHighAccuracyEnabled: true), .danger)
    }

    func testSpeechRouteDecisionChineseMessages() {
        XCTAssertEqual(
            SpeechRecognitionRouteDecision(backend: .fastSystem, fallbackReason: nil).readyTypeDisplayMessage,
            "本次使用极速识别"
        )
        XCTAssertEqual(
            SpeechRecognitionRouteDecision(backend: .highAccuracyLocal, fallbackReason: nil).readyTypeDisplayMessage,
            "本次使用高精度识别"
        )
        XCTAssertEqual(
            SpeechRecognitionRouteDecision(backend: .fastSystem, fallbackReason: "高精度识别未就绪，已使用极速识别。").readyTypeDisplayMessage,
            "高精度识别未就绪，已使用极速识别。"
        )
    }

    func testSpeechRouteDecisionLastRunMessages() {
        XCTAssertEqual(
            SpeechRecognitionRouteDecision(backend: .fastSystem, fallbackReason: nil).readyTypeLastRunDisplayMessage,
            "上次识别：极速识别"
        )
        XCTAssertEqual(
            SpeechRecognitionRouteDecision(backend: .highAccuracyLocal, fallbackReason: nil).readyTypeLastRunDisplayMessage,
            "上次识别：高精度识别"
        )
        XCTAssertEqual(
            SpeechRecognitionRouteDecision(backend: .fastSystem, fallbackReason: "高精度识别失败，已使用极速识别。").readyTypeLastRunDisplayMessage,
            "上次识别：高精度识别失败，已使用极速识别。"
        )
    }

    func testSpeechRouteDecisionStatusRoles() {
        XCTAssertEqual(
            SpeechRecognitionRouteDecision(backend: .fastSystem, fallbackReason: nil).readyTypeStatusRole,
            .neutral
        )
        XCTAssertEqual(
            SpeechRecognitionRouteDecision(backend: .highAccuracyLocal, fallbackReason: nil).readyTypeStatusRole,
            .success
        )
        XCTAssertEqual(
            SpeechRecognitionRouteDecision(backend: .fastSystem, fallbackReason: "高精度识别未就绪，已使用极速识别。").readyTypeStatusRole,
            .warning
        )
    }
}
