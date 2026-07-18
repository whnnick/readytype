import CryptoKit
import Foundation
import XCTest
@testable import ReadyType

@MainActor
final class HotVocabularyCoordinatorTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testCachedPackBecomesReadyWithoutNetworkRequest() throws {
        let context = try makeContext(withInstalledPack: true)
        defer { context.cleanup() }

        context.coordinator.loadCachedPack(now: now)

        XCTAssertEqual(context.coordinator.status.currentVersion, "2027.01.14")
        XCTAssertEqual(context.coordinator.activePack?.pack.terms.map(\.value), ["流浪地球三"])
    }

    func testFailedUpdateKeepsCachedPackAvailable() async throws {
        let context = try makeContext(withInstalledPack: true)
        defer { context.cleanup() }
        context.coordinator.loadCachedPack(now: now)

        await context.coordinator.update(force: true, now: now)

        XCTAssertEqual(context.coordinator.status, .unavailable(currentVersion: "2027.01.14"))
        XCTAssertEqual(context.coordinator.activePack?.pack.terms.map(\.value), ["流浪地球三"])
    }

    func testFailedFirstUpdateReportsUnavailableWithoutInventingContent() async throws {
        let context = try makeContext(withInstalledPack: false)
        defer { context.cleanup() }

        await context.coordinator.update(force: true, now: now)

        XCTAssertEqual(context.coordinator.status, .unavailable(currentVersion: nil))
        XCTAssertNil(context.coordinator.activePack)
    }

    private func makeContext(withInstalledPack: Bool) throws -> CoordinatorTestContext {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReadyTypeHotVocabularyCoordinatorTests-\(UUID().uuidString)", isDirectory: true)
        let privateKey = Curve25519.Signing.PrivateKey()
        let verifier = try HotVocabularyVerifier(
            publicKeyData: privateKey.publicKey.rawRepresentation,
            currentAppVersion: "1.4.0"
        )
        let store = HotVocabularyStore(rootDirectory: directory, verifier: verifier)
        if withInstalledPack {
            let fixture = try signedFixture(privateKey: privateKey)
            try store.install(
                manifestData: fixture.manifest,
                packData: fixture.pack,
                now: now
            )
        }
        let updater = HotVocabularyUpdater(
            manifestURL: HotVocabularyProductionConfiguration.manifestURL,
            fetcher: AlwaysFailingVocabularyFetcher(),
            store: store,
            stateStore: CoordinatorUpdateStateStore()
        )
        return CoordinatorTestContext(
            directory: directory,
            coordinator: HotVocabularyCoordinator(store: store, updater: updater)
        )
    }

    private func signedFixture(
        privateKey: Curve25519.Signing.PrivateKey
    ) throws -> (manifest: Data, pack: Data) {
        let pack = HotVocabularyPack(
            packVersion: "2027.01.14",
            terms: [
                HotVocabularyTerm(
                    value: "流浪地球三",
                    category: "movie",
                    sourceID: "wikidata:Q1",
                    weight: 80,
                    expiresAt: now.addingTimeInterval(86_400)
                )
            ]
        )
        let packData = try HotVocabularyCoding.encoder.encode(pack)
        var manifest = HotVocabularyManifest(
            schemaVersion: 1,
            packVersion: pack.packVersion,
            generatedAt: now.addingTimeInterval(-60),
            expiresAt: now.addingTimeInterval(86_400),
            minimumAppVersion: "1.4.0",
            contentSHA256: HotVocabularyVerifier.sha256Hex(packData),
            signature: ""
        )
        manifest.signature = try privateKey.signature(for: manifest.signedPayload).base64EncodedString()
        return (try HotVocabularyCoding.encoder.encode(manifest), packData)
    }
}

private struct CoordinatorTestContext {
    let directory: URL
    let coordinator: HotVocabularyCoordinator

    func cleanup() {
        try? FileManager.default.removeItem(at: directory)
    }
}

private struct AlwaysFailingVocabularyFetcher: HotVocabularyRemoteFetching {
    func fetch(url: URL, ifNoneMatch: String?) async throws -> HotVocabularyHTTPResponse {
        throw URLError(.notConnectedToInternet)
    }
}

private actor CoordinatorUpdateStateStore: HotVocabularyUpdateStatePersisting {
    private var state = HotVocabularyUpdateState()

    func load() -> HotVocabularyUpdateState { state }
    func save(_ state: HotVocabularyUpdateState) { self.state = state }
}
