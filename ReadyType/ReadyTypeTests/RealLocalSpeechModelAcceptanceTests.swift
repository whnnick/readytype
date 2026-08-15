import XCTest
@testable import ReadyType

final class RealLocalSpeechModelAcceptanceTests: XCTestCase {
    @MainActor
    func testExplicitAudioFixtureReportsWarmHighAccuracyLatency() async throws {
        let environment = ProcessInfo.processInfo.environment
        try XCTSkipUnless(
            environment["READYTYPE_SPEECH_AUDIO_FIXTURE"] != nil,
            "Set READYTYPE_SPEECH_AUDIO_FIXTURE to a local audio file for an explicit diagnostic run."
        )
        let fixturePath = try XCTUnwrap(
            environment["READYTYPE_SPEECH_AUDIO_FIXTURE"]
        )
        try XCTSkipUnless(
            environment["RUN_LOCAL_SPEECH_MODEL"] == "1",
            "Set RUN_LOCAL_SPEECH_MODEL=1 to run the real high-accuracy speech diagnostic."
        )

        let fixtureURL = URL(fileURLWithPath: fixturePath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixtureURL.path))

        let engine = CoreMLHighAccuracySpeechEngine()
        let warmupStartedAt = Date()
        try await engine.prewarm()
        let warmupMilliseconds = Int(Date().timeIntervalSince(warmupStartedAt) * 1_000)

        let transcriptionStartedAt = Date()
        let transcript = try await engine.transcribeAudio(
            at: fixtureURL,
            contextualTerms: ["ReadyType", "GitHub", "DeepSeek"]
        )
        let transcriptionMilliseconds = Int(Date().timeIntervalSince(transcriptionStartedAt) * 1_000)

        XCTAssertFalse(transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        print("Real high-accuracy warmup: \(warmupMilliseconds)ms")
        print("Real high-accuracy transcription: \(transcriptionMilliseconds)ms")
        print("Real high-accuracy transcript: \(transcript)")
    }

    @MainActor
    func testDefaultSpeechPackageCanDownloadAndPrewarm() async throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["RUN_LOCAL_SPEECH_MODEL"] == "1",
            "Set RUN_LOCAL_SPEECH_MODEL=1 to download or reuse the real high-accuracy speech package."
        )

        let manager = LocalSpeechModelManager()
        let service = LocalSpeechModelDownloadService(manager: manager)
        let initialState = manager.state()
        let finalState: LocalSpeechModelState

        if initialState == .downloadedCold {
            finalState = initialState
        } else {
            finalState = await service.downloadDefaultModel()
        }

        XCTAssertEqual(finalState, .downloadedCold)

        let installedModelURL = try XCTUnwrap(manager.installedModelURL())
        XCTAssertEqual(installedModelURL.lastPathComponent, LocalSpeechModelManager.defaultWhisperKitModelFolderName)

        let warmupService = LocalSpeechModelWarmupService(
            initialState: manager.state(),
            policy: .alwaysAllow,
            warmup: {
                try await CoreMLHighAccuracySpeechEngine(modelManager: manager).prewarm()
            }
        )

        await warmupService.prewarmIfAllowed(reason: "1.0.0 local speech-package acceptance")
        XCTAssertEqual(warmupService.state, .warm)
    }

    @MainActor
    func testInstalledSpeechPackageCanBeTemporarilyRemovedAndFallbackRemainsClear() async throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["RUN_LOCAL_SPEECH_MODEL"] == "1",
            "Set RUN_LOCAL_SPEECH_MODEL=1 to run real high-accuracy speech-package recovery acceptance."
        )

        let manager = LocalSpeechModelManager()
        if manager.installedModelURL() == nil {
            let installedState = await LocalSpeechModelDownloadService(manager: manager).downloadDefaultModel()
            XCTAssertEqual(installedState, .downloadedCold)
        }

        let installedModelURL = try XCTUnwrap(manager.installedModelURL())
        let backupURL = installedModelURL
            .deletingLastPathComponent()
            .appendingPathComponent("\(installedModelURL.lastPathComponent).acceptance-backup-\(UUID().uuidString)")
        let fileManager = FileManager.default

        try fileManager.moveItem(at: installedModelURL, to: backupURL)
        defer {
            if fileManager.fileExists(atPath: backupURL.path),
               !fileManager.fileExists(atPath: installedModelURL.path) {
                try? fileManager.moveItem(at: backupURL, to: installedModelURL)
            }
        }

        XCTAssertEqual(manager.state(), .notInstalled)
        XCTAssertNil(manager.installedModelURL())

        let decision = SpeechRecognitionRouter().route(
            context: SpeechRecognitionRouteContext(
                mode: .highAccuracyLocal,
                scenario: .document,
                frontmostAppBundleIdentifier: "md.obsidian",
                recordingDuration: 20,
                hasLowConfidenceSignal: false,
                hasChineseMisclassifiedAsEnglishSignal: false,
                isLowPowerModeEnabled: false,
                localModelState: manager.state(),
                contextualTerms: ["ReadyType"]
            )
        )

        XCTAssertEqual(decision.backend, .fastSystem)
        XCTAssertEqual(decision.fallbackReason, "高精度识别未就绪，已使用极速识别。")

        let failingService = LocalSpeechModelDownloadService(
            manager: manager,
            installer: FailingAcceptanceModelInstaller()
        )
        let failedState = await failingService.downloadDefaultModel()
        XCTAssertEqual(failedState, .failed(reason: "高精度语音包下载失败：未生成模型目录"))
        XCTAssertNil(manager.installedModelURL())
    }
}

@MainActor
private final class FailingAcceptanceModelInstaller: LocalSpeechModelInstalling {
    func installModel(
        _ manifest: LocalSpeechModelManifest,
        using manager: LocalSpeechModelManager,
        progress: @escaping (Double) -> Void
    ) async throws {
        progress(1)
        throw LocalSpeechModelDownloadError.downloadDidNotProduceModel
    }
}
