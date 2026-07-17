import CryptoKit
import XCTest
@testable import ReadyType

final class HotVocabularyStoreTests: XCTestCase {
    private var temporaryDirectory: URL!
    private var privateKey: Curve25519.Signing.PrivateKey!
    private var verifier: HotVocabularyVerifier!
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUpWithError() throws {
        try super.setUpWithError()
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReadyTypeHotVocabularyStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        privateKey = Curve25519.Signing.PrivateKey()
        verifier = try HotVocabularyVerifier(
            publicKeyData: privateKey.publicKey.rawRepresentation,
            currentAppVersion: "1.4.0"
        )
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        verifier = nil
        privateKey = nil
        temporaryDirectory = nil
        try super.tearDownWithError()
    }

    func testInstallPersistsVerifiedPackAcrossStoreRecreation() throws {
        let fixture = try signedPack(version: "2026.07.17", term: "流浪地球三")
        let store = HotVocabularyStore(rootDirectory: temporaryDirectory, verifier: verifier)

        let installed = try store.install(
            manifestData: fixture.manifestData,
            packData: fixture.packData,
            now: now
        )
        let relaunchedStore = HotVocabularyStore(rootDirectory: temporaryDirectory, verifier: verifier)

        XCTAssertEqual(installed.pack.terms.map(\.value), ["流浪地球三"])
        XCTAssertEqual(try relaunchedStore.loadActive(now: now)?.pack, installed.pack)
    }

    func testRejectedInstallKeepsPreviouslyActivePack() throws {
        let first = try signedPack(version: "2026.07.17", term: "流浪地球三")
        let second = try signedPack(version: "2026.07.18", term: "ReadyType")
        let store = HotVocabularyStore(rootDirectory: temporaryDirectory, verifier: verifier)
        try store.install(manifestData: first.manifestData, packData: first.packData, now: now)
        var corruptedData = second.packData
        corruptedData.append(0)

        XCTAssertThrowsError(
            try store.install(
                manifestData: second.manifestData,
                packData: corruptedData,
                now: now
            )
        )
        XCTAssertEqual(try store.loadActive(now: now)?.pack.terms.map(\.value), ["流浪地球三"])
    }

    func testLoadFallsBackToPreviousPackWhenCurrentFilesAreCorrupt() throws {
        let first = try signedPack(version: "2026.07.17", term: "流浪地球三")
        let second = try signedPack(version: "2026.07.18", term: "ReadyType")
        let store = HotVocabularyStore(rootDirectory: temporaryDirectory, verifier: verifier)
        try store.install(manifestData: first.manifestData, packData: first.packData, now: now)
        try store.install(manifestData: second.manifestData, packData: second.packData, now: now)
        let activePackURL = try XCTUnwrap(store.activePackFileURL())
        try Data("corrupt".utf8).write(to: activePackURL, options: .atomic)

        let loaded = try store.loadActive(now: now)

        XCTAssertEqual(loaded?.pack.terms.map(\.value), ["流浪地球三"])
    }

    private func signedPack(version: String, term: String) throws -> (manifestData: Data, packData: Data) {
        let pack = HotVocabularyPack(
            packVersion: version,
            terms: [
                HotVocabularyTerm(
                    value: term,
                    category: "other",
                    sourceID: "wikidata:test",
                    weight: 80
                )
            ]
        )
        let packData = try HotVocabularyCoding.encoder.encode(pack)
        var manifest = HotVocabularyManifest(
            schemaVersion: 1,
            packVersion: version,
            generatedAt: now.addingTimeInterval(-60),
            expiresAt: now.addingTimeInterval(86_400),
            minimumAppVersion: "1.0.0",
            contentSHA256: HotVocabularyVerifier.sha256Hex(packData),
            signature: ""
        )
        manifest.signature = try privateKey.signature(for: manifest.signedPayload).base64EncodedString()
        return (
            try HotVocabularyCoding.encoder.encode(manifest),
            packData
        )
    }
}
