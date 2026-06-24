import CryptoKit
import XCTest
@testable import ReadyType

final class LocalSpeechModelManagerTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReadyTypeLocalSpeechModelManagerTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }

        temporaryDirectory = nil
        try super.tearDownWithError()
    }

    func testStateIsNotInstalledWhenNoModelFileExists() {
        let manager = makeManager()

        XCTAssertEqual(manager.state(), .notInstalled)
        XCTAssertNil(manager.installedModelURL())
    }

    func testStateIsDownloadedColdWhenModelExistsAndChecksumMatches() throws {
        let modelData = Data("valid model".utf8)
        let modelURL = try writeModel(named: "test-model.bin", data: modelData)
        let manager = makeManager(expectedSHA256: sha256Hex(modelData))

        XCTAssertEqual(manager.state(), .downloadedCold)
        XCTAssertEqual(manager.installedModelURL(), modelURL)
    }

    func testStateIsDownloadedColdWhenModelExistsAndSHA1ChecksumMatches() throws {
        let modelData = Data("valid sha1 model".utf8)
        let modelURL = try writeModel(named: "test-model.bin", data: modelData)
        let manager = LocalSpeechModelManager(
            modelsDirectory: temporaryDirectory,
            manifests: [
                LocalSpeechModelManifest(
                    fileName: "test-model.bin",
                    expectedSHA1: sha1Hex(modelData)
                )
            ]
        )

        XCTAssertEqual(manager.state(), .downloadedCold)
        XCTAssertEqual(manager.installedModelURL(), modelURL)
    }

    func testDefaultDownloadManifestUsesWhisperKitCoreMLModel() throws {
        let manager = LocalSpeechModelManager()

        let manifest = try XCTUnwrap(manager.defaultDownloadManifest())

        XCTAssertEqual(manifest.fileName, LocalSpeechModelManager.defaultWhisperKitModelFolderName)
        XCTAssertNil(manifest.expectedChecksum)
        XCTAssertNil(manifest.downloadURL)
        XCTAssertEqual(manifest.sizeDescription, "约 626 MiB")
    }

    func testStateFailsWhenDefaultModelDirectoryIsEmpty() throws {
        try FileManager.default.createDirectory(
            at: temporaryDirectory.appendingPathComponent(LocalSpeechModelManager.defaultWhisperKitModelFolderName, isDirectory: true),
            withIntermediateDirectories: true
        )
        let manager = LocalSpeechModelManager(modelsDirectory: temporaryDirectory)

        XCTAssertEqual(
            manager.state(),
            .failed(reason: "模型校验失败：\(LocalSpeechModelManager.defaultWhisperKitModelFolderName)")
        )
        XCTAssertNil(manager.installedModelURL())
    }

    func testStateFailsWhenChecksumDoesNotMatch() throws {
        let modelData = Data("corrupt model".utf8)
        try writeModel(named: "test-model.bin", data: modelData)
        let manager = makeManager(expectedSHA256: sha256Hex(Data("expected model".utf8)))

        XCTAssertEqual(manager.state(), .failed(reason: "模型校验失败：test-model.bin"))
    }

    func testDeleteInstalledModelsRemovesKnownModelFiles() throws {
        try writeModelDirectory(named: LocalSpeechModelManager.defaultWhisperKitModelFolderName)
        let manager = LocalSpeechModelManager(modelsDirectory: temporaryDirectory)

        try manager.deleteInstalledModels()

        XCTAssertEqual(manager.state(), .notInstalled)
        XCTAssertNil(manager.installedModelURL())
    }

    private func writeModelDirectory(named fileName: String) throws {
        let url = temporaryDirectory.appendingPathComponent(fileName, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try Data("model".utf8).write(to: url.appendingPathComponent("TextDecoder.mlmodelc"))
    }

    @discardableResult
    private func writeModel(named fileName: String, data: Data) throws -> URL {
        let url = temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: url)
        return url
    }

    private func makeManager(expectedSHA256: String? = nil) -> LocalSpeechModelManager {
        LocalSpeechModelManager(
            modelsDirectory: temporaryDirectory,
            manifests: [
                LocalSpeechModelManifest(
                    fileName: "test-model.bin",
                    expectedSHA256: expectedSHA256
                )
            ]
        )
    }

    private func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private func sha1Hex(_ data: Data) -> String {
        Insecure.SHA1.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
