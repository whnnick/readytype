import XCTest
@testable import ReadyType

final class LocalSpeechModelUpdateCheckerTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReadyTypeLocalSpeechModelUpdateCheckerTests-\(UUID().uuidString)")
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
    func testCheckReportsNotInstalledBeforeModelExists() async {
        let manager = LocalSpeechModelManager(modelsDirectory: temporaryDirectory)
        let checker = LocalSpeechModelUpdateChecker(
            manager: manager,
            manifestFetcher: StubManifestFetcher(
                result: .success(LocalSpeechModelManager.defaultManifests[0])
            )
        )

        let status = await checker.checkForUpdates()

        XCTAssertEqual(status, .notInstalled)
    }

    @MainActor
    func testCheckReportsUpToDateWhenInstalledManifestMatchesLatestManifest() async throws {
        let manifest = LocalSpeechModelManager.defaultManifests[0]
        let manager = LocalSpeechModelManager(modelsDirectory: temporaryDirectory)
        try writeModelDirectory(for: manifest, manager: manager)
        let checker = LocalSpeechModelUpdateChecker(
            manager: manager,
            manifestFetcher: StubManifestFetcher(result: .success(manifest))
        )

        let status = await checker.checkForUpdates()

        XCTAssertEqual(status, .upToDate(version: manifest.version))
    }

    @MainActor
    func testCheckReportsUpdateAvailableWhenLatestManifestDiffers() async throws {
        let currentManifest = LocalSpeechModelManager.defaultManifests[0]
        let latestManifest = LocalSpeechModelManifest(
            fileName: "openai_whisper-large-v3-v20250101_626MB",
            version: "2025-01-01",
            sizeDescription: "约 626 MiB"
        )
        let manager = LocalSpeechModelManager(modelsDirectory: temporaryDirectory)
        try writeModelDirectory(for: currentManifest, manager: manager)
        let checker = LocalSpeechModelUpdateChecker(
            manager: manager,
            manifestFetcher: StubManifestFetcher(result: .success(latestManifest))
        )

        let status = await checker.checkForUpdates()

        XCTAssertEqual(
            status,
            .updateAvailable(
                currentVersion: currentManifest.version,
                latestManifest: latestManifest
            )
        )
    }

    @MainActor
    func testCheckFailureUsesTemporaryUnableToCheckState() async throws {
        let manifest = LocalSpeechModelManager.defaultManifests[0]
        let manager = LocalSpeechModelManager(modelsDirectory: temporaryDirectory)
        try writeModelDirectory(for: manifest, manager: manager)
        let checker = LocalSpeechModelUpdateChecker(
            manager: manager,
            manifestFetcher: StubManifestFetcher(result: .failure(URLError(.notConnectedToInternet)))
        )

        let status = await checker.checkForUpdates()

        XCTAssertEqual(status, .unableToCheck(reason: "暂时无法检查更新"))
    }

    func testRemoteManifestDecoderAcceptsVerifiedWhisperKitVariant() throws {
        let data = Data(#"{"schemaVersion":1,"recommendedModel":{"variant":"large-v3-v20240930_626MB","folderName":"openai_whisper-large-v3-v20240930_626MB","version":"2024-09-30","sizeDescription":"约 626 MiB"}}"#.utf8)

        let manifest = try RemoteLocalSpeechModelManifestDecoder().decode(data)

        XCTAssertEqual(manifest.modelName, "large-v3-v20240930_626MB")
        XCTAssertEqual(manifest.fileName, "openai_whisper-large-v3-v20240930_626MB")
        XCTAssertEqual(manifest.version, "2024-09-30")
    }

    func testRemoteManifestDecoderRejectsUnknownSchema() {
        let data = Data(#"{"schemaVersion":2,"recommendedModel":{"variant":"large-v3-v20240930_626MB","folderName":"openai_whisper-large-v3-v20240930_626MB","version":"2024-09-30"}}"#.utf8)

        XCTAssertThrowsError(try RemoteLocalSpeechModelManifestDecoder().decode(data)) { error in
            XCTAssertEqual(error as? RemoteLocalSpeechModelManifestError, .unsupportedSchema)
        }
    }

    func testRemoteManifestDecoderRejectsArbitraryFolder() {
        let data = Data(#"{"schemaVersion":1,"recommendedModel":{"variant":"large-v3-v20240930_626MB","folderName":"../../OtherModel","version":"2024-09-30"}}"#.utf8)

        XCTAssertThrowsError(try RemoteLocalSpeechModelManifestDecoder().decode(data)) { error in
            XCTAssertEqual(error as? RemoteLocalSpeechModelManifestError, .invalidModel)
        }
    }

    private func writeModelDirectory(
        for manifest: LocalSpeechModelManifest,
        manager: LocalSpeechModelManager
    ) throws {
        let modelDirectory = manager.destinationURL(for: manifest)
        try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
        try Data("model".utf8).write(to: modelDirectory.appendingPathComponent("TextDecoder.mlmodelc"))
    }
}

private final class StubManifestFetcher: LocalSpeechModelManifestFetching {
    let result: Result<LocalSpeechModelManifest, Error>

    init(result: Result<LocalSpeechModelManifest, Error>) {
        self.result = result
    }

    func latestManifest() async throws -> LocalSpeechModelManifest {
        try result.get()
    }
}
