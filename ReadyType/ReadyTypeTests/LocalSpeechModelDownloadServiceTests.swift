import XCTest
@testable import ReadyType

final class LocalSpeechModelDownloadServiceTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReadyTypeLocalSpeechModelDownloadServiceTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }

        temporaryDirectory = nil
        try super.tearDownWithError()
    }

    @MainActor
    func testDownloadDefaultModelInstallsWhisperKitDirectoryAndTracksProgress() async throws {
        let installer = FakeModelInstaller(progressValues: [0.25, 1.2])
        let manager = LocalSpeechModelManager(modelsDirectory: temporaryDirectory)
        var observedStates: [LocalSpeechModelState] = []
        let service = LocalSpeechModelDownloadService(
            manager: manager,
            installer: installer,
            onStateChange: { observedStates.append($0) }
        )

        let finalState = await service.downloadDefaultModel()

        XCTAssertEqual(finalState, .downloadedCold)
        XCTAssertEqual(service.state, .downloadedCold)
        XCTAssertEqual(installer.installCallCount, 1)
        XCTAssertEqual(observedStates, [.downloading(progress: 0), .downloading(progress: 0.25), .downloading(progress: 1.0), .downloadedCold])
        XCTAssertEqual(manager.installedModelURL()?.lastPathComponent, LocalSpeechModelManager.defaultWhisperKitModelFolderName)
    }

    @MainActor
    func testDownloadDefaultModelReportsFailureWhenInstallerFails() async throws {
        let installer = FakeModelInstaller(
            progressValues: [1.0],
            error: LocalSpeechModelDownloadError.downloadDidNotProduceModel
        )
        let manager = LocalSpeechModelManager(modelsDirectory: temporaryDirectory)
        let service = LocalSpeechModelDownloadService(manager: manager, installer: installer)

        let finalState = await service.downloadDefaultModel()

        XCTAssertEqual(finalState, .failed(reason: "高精度语音包下载失败：未生成模型目录"))
        XCTAssertEqual(service.state, finalState)
        XCTAssertNil(manager.installedModelURL())
    }

    @MainActor
    func testLateProgressDoesNotOverwriteInstalledState() async throws {
        let installer = LateProgressModelInstaller()
        let service = LocalSpeechModelDownloadService(
            manager: LocalSpeechModelManager(modelsDirectory: temporaryDirectory),
            installer: installer
        )

        let finalState = await service.downloadDefaultModel()
        installer.reportLateProgress(1.0)

        XCTAssertEqual(finalState, .downloadedCold)
        XCTAssertEqual(service.state, .downloadedCold)
    }

    @MainActor
    func testModelUpdatePersistsNewManifestAndRemovesPreviousModelAfterSuccess() async throws {
        let manager = LocalSpeechModelManager(modelsDirectory: temporaryDirectory)
        let currentManifest = LocalSpeechModelManager.defaultManifests[0]
        let currentURL = manager.destinationURL(for: currentManifest)
        try FileManager.default.createDirectory(at: currentURL, withIntermediateDirectories: true)
        try Data("old".utf8).write(to: currentURL.appendingPathComponent("TextDecoder.mlmodelc"))
        let updatedManifest = LocalSpeechModelManifest(
            fileName: "openai_whisper-large-v3-v20250101_626MB",
            modelName: "large-v3-v20250101_626MB",
            version: "2025-01-01"
        )
        let service = LocalSpeechModelDownloadService(
            manager: manager,
            installer: FakeModelInstaller(progressValues: [1])
        )

        let finalState = await service.downloadModel(updatedManifest)

        XCTAssertEqual(finalState, .downloadedCold)
        XCTAssertEqual(manager.installedManifest(), updatedManifest)
        XCTAssertFalse(FileManager.default.fileExists(atPath: currentURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: manager.destinationURL(for: updatedManifest).path))
    }

    @MainActor
    func testModelUpdateFailureKeepsPreviousModelAvailable() async throws {
        let manager = LocalSpeechModelManager(modelsDirectory: temporaryDirectory)
        let currentManifest = LocalSpeechModelManager.defaultManifests[0]
        let currentURL = manager.destinationURL(for: currentManifest)
        try FileManager.default.createDirectory(at: currentURL, withIntermediateDirectories: true)
        try Data("old".utf8).write(to: currentURL.appendingPathComponent("TextDecoder.mlmodelc"))
        let updatedManifest = LocalSpeechModelManifest(
            fileName: "openai_whisper-large-v3-v20250101_626MB",
            modelName: "large-v3-v20250101_626MB",
            version: "2025-01-01"
        )
        let installer = FakeModelInstaller(
            progressValues: [0.5],
            error: LocalSpeechModelDownloadError.downloadDidNotProduceModel
        )
        let service = LocalSpeechModelDownloadService(manager: manager, installer: installer)

        let finalState = await service.downloadModel(updatedManifest)

        XCTAssertEqual(finalState, .failed(reason: "高精度语音包下载失败：未生成模型目录"))
        XCTAssertEqual(manager.installedManifest(), currentManifest)
        XCTAssertTrue(FileManager.default.fileExists(atPath: currentURL.path))
    }
}

@MainActor
private final class FakeModelInstaller: LocalSpeechModelInstalling {
    private let progressValues: [Double]
    private let error: Error?
    private(set) var installCallCount = 0

    init(progressValues: [Double], error: Error? = nil) {
        self.progressValues = progressValues
        self.error = error
    }

    func installModel(
        _ manifest: LocalSpeechModelManifest,
        using manager: LocalSpeechModelManager,
        progress: @escaping (Double) -> Void
    ) async throws {
        installCallCount += 1
        for value in progressValues {
            progress(value)
        }

        if let error {
            throw error
        }

        let destinationURL = manager.destinationURL(for: manifest)
        try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)
        try Data("model".utf8).write(to: destinationURL.appendingPathComponent("TextDecoder.mlmodelc"))
    }
}

@MainActor
private final class LateProgressModelInstaller: LocalSpeechModelInstalling {
    private var progress: ((Double) -> Void)?

    func installModel(
        _ manifest: LocalSpeechModelManifest,
        using manager: LocalSpeechModelManager,
        progress: @escaping (Double) -> Void
    ) async throws {
        self.progress = progress
        let destinationURL = manager.destinationURL(for: manifest)
        try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)
        try Data("model".utf8).write(to: destinationURL.appendingPathComponent("TextDecoder.mlmodelc"))
    }

    func reportLateProgress(_ value: Double) {
        progress?(value)
    }
}
