import XCTest

final class SettingsUserFacingCopyTests: XCTestCase {
    func testSettingsPaneCopyAvoidsTechnicalImplementationTerms() throws {
        let source = try userFacingSources().joined(separator: "\n")
        let bannedVisibleTerms = [
            "不新增 provider",
            "粘贴 pipeline",
            "本地模型",
            "API Key",
            "Base URL",
            "准确率增强包",
            "本机语音包",
            "词库",
            "术语库",
            "记忆建议",
            "记住写法"
        ]

        for term in bannedVisibleTerms {
            XCTAssertFalse(source.contains(term), "Settings user-facing copy should avoid: \(term)")
        }
    }

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func userFacingSources() throws -> [String] {
        let root = repositoryRoot()
        let relativePaths = [
            "ReadyType/ReadyType/Settings/SettingsPane.swift",
            "ReadyType/ReadyType/Settings/APIConnectionTestState.swift",
            "ReadyType/ReadyType/Settings/APIConnectionTester.swift",
            "ReadyType/ReadyType/Permissions/PermissionsPane.swift",
            "ReadyType/ReadyType/App/AboutPane.swift",
            "ReadyType/ReadyType/App/ConsoleView.swift"
        ]

        return try relativePaths.map { path in
            try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
        }
    }
}
