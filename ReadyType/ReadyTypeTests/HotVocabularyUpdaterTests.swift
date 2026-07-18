import CryptoKit
import XCTest
@testable import ReadyType

final class HotVocabularyUpdaterTests: XCTestCase {
    private var temporaryDirectory: URL!
    private var privateKey: Curve25519.Signing.PrivateKey!
    private var store: HotVocabularyStore!
    private let manifestURL = URL(string: "https://whnnick.github.io/readytype/vocabulary/v1/manifest.json")!
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUpWithError() throws {
        try super.setUpWithError()
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReadyTypeHotVocabularyUpdaterTests-\(UUID().uuidString)", isDirectory: true)
        privateKey = Curve25519.Signing.PrivateKey()
        let verifier = try HotVocabularyVerifier(
            publicKeyData: privateKey.publicKey.rawRepresentation,
            currentAppVersion: "1.4.0"
        )
        store = HotVocabularyStore(rootDirectory: temporaryDirectory, verifier: verifier)
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        store = nil
        privateKey = nil
        temporaryDirectory = nil
        try super.tearDownWithError()
    }

    func testSuccessfulUpdateInstallsPackAndPersistsETag() async throws {
        let fixture = try signedPack(version: "2026.07.18", term: "流浪地球三")
        let fetcher = StubHotVocabularyFetcher(responses: [
            .ok(url: manifestURL, data: fixture.manifestData, etag: "manifest-v1"),
            .ok(url: manifestURL.deletingLastPathComponent().appendingPathComponent("pack.json"), data: fixture.packData)
        ])
        let stateStore = InMemoryHotVocabularyUpdateStateStore()
        let updater = HotVocabularyUpdater(
            manifestURL: manifestURL,
            fetcher: fetcher,
            store: store,
            stateStore: stateStore
        )

        let result = await updater.update(now: now)

        XCTAssertEqual(result, .installed(version: "2026.07.18"))
        XCTAssertEqual(try store.loadActive(now: now)?.pack.terms.map(\.value), ["流浪地球三"])
        let state = await stateStore.load()
        XCTAssertEqual(state.etag, "manifest-v1")
        XCTAssertEqual(state.lastCheckedAt, now)
    }

    func testAutomaticUpdateSkipsWhenCheckedWithinTwentyFourHours() async {
        let stateStore = InMemoryHotVocabularyUpdateStateStore(
            initial: HotVocabularyUpdateState(lastCheckedAt: now.addingTimeInterval(-60), etag: "manifest-v1")
        )
        let fetcher = StubHotVocabularyFetcher(responses: [])
        let updater = HotVocabularyUpdater(
            manifestURL: manifestURL,
            fetcher: fetcher,
            store: store,
            stateStore: stateStore
        )

        let result = await updater.update(now: now)
        let requestCount = await fetcher.requestCount()

        XCTAssertEqual(result, .skippedRecentCheck)
        XCTAssertEqual(requestCount, 0)
    }

    func testForcedUpdateBypassesDailyLimitAndUsesStoredETag() async throws {
        let current = try signedPack(version: "2026.07.18", term: "流浪地球三")
        try store.install(manifestData: current.manifestData, packData: current.packData, now: now)
        let stateStore = InMemoryHotVocabularyUpdateStateStore(
            initial: HotVocabularyUpdateState(lastCheckedAt: now.addingTimeInterval(-60), etag: "manifest-v1")
        )
        let fetcher = StubHotVocabularyFetcher(responses: [
            HotVocabularyHTTPResponse(url: manifestURL, statusCode: 304, data: nil, etag: "manifest-v1")
        ])
        let updater = HotVocabularyUpdater(
            manifestURL: manifestURL,
            fetcher: fetcher,
            store: store,
            stateStore: stateStore
        )

        let result = await updater.update(force: true, now: now)
        let requestedETags = await fetcher.requestedETags()

        XCTAssertEqual(result, .notModified(version: "2026.07.18"))
        XCTAssertEqual(requestedETags, ["manifest-v1"])
    }

    func testNotModifiedResponseRefetchesWithoutETagWhenLocalPackIsMissing() async throws {
        let fixture = try signedPack(version: "2026.07.18", term: "流浪地球三")
        let packURL = manifestURL.deletingLastPathComponent().appendingPathComponent("pack.json")
        let stateStore = InMemoryHotVocabularyUpdateStateStore(
            initial: HotVocabularyUpdateState(lastCheckedAt: nil, etag: "manifest-v1")
        )
        let fetcher = StubHotVocabularyFetcher(responses: [
            HotVocabularyHTTPResponse(url: manifestURL, statusCode: 304, data: nil, etag: "manifest-v1"),
            .ok(url: manifestURL, data: fixture.manifestData, etag: "manifest-v1"),
            .ok(url: packURL, data: fixture.packData)
        ])
        let updater = HotVocabularyUpdater(
            manifestURL: manifestURL,
            fetcher: fetcher,
            store: store,
            stateStore: stateStore
        )

        let result = await updater.update(force: true, now: now)
        let requestedETags = await fetcher.requestedETags()

        XCTAssertEqual(result, .installed(version: "2026.07.18"))
        XCTAssertEqual(requestedETags, ["manifest-v1", nil, nil])
    }

    func testInvalidDownloadedPackKeepsCurrentPackAndDoesNotAdvanceETag() async throws {
        let current = try signedPack(version: "2026.07.17", term: "当前词条")
        try store.install(manifestData: current.manifestData, packData: current.packData, now: now)
        let next = try signedPack(version: "2026.07.18", term: "新版词条")
        var corruptPack = next.packData
        corruptPack.append(0)
        let fetcher = StubHotVocabularyFetcher(responses: [
            .ok(url: manifestURL, data: next.manifestData, etag: "manifest-v2"),
            .ok(url: manifestURL.deletingLastPathComponent().appendingPathComponent("pack.json"), data: corruptPack)
        ])
        let stateStore = InMemoryHotVocabularyUpdateStateStore(
            initial: HotVocabularyUpdateState(lastCheckedAt: nil, etag: "manifest-v1")
        )
        let updater = HotVocabularyUpdater(
            manifestURL: manifestURL,
            fetcher: fetcher,
            store: store,
            stateStore: stateStore
        )

        let result = await updater.update(now: now)
        let savedState = await stateStore.load()

        XCTAssertEqual(result, .failed(.verification))
        XCTAssertEqual(try store.loadActive(now: now)?.pack.terms.map(\.value), ["当前词条"])
        XCTAssertEqual(savedState.etag, "manifest-v1")
    }

    func testManifestCannotRedirectPackDownloadToAnotherHost() async throws {
        let fixture = try signedPack(
            version: "2026.07.18",
            term: "流浪地球三",
            contentPath: "https://example.com/pack.json"
        )
        let fetcher = StubHotVocabularyFetcher(responses: [
            .ok(url: manifestURL, data: fixture.manifestData, etag: "manifest-v2")
        ])
        let updater = HotVocabularyUpdater(
            manifestURL: manifestURL,
            fetcher: fetcher,
            store: store,
            stateStore: InMemoryHotVocabularyUpdateStateStore()
        )

        let result = await updater.update(now: now)
        let requestCount = await fetcher.requestCount()

        XCTAssertEqual(result, .failed(.invalidResponse))
        XCTAssertEqual(requestCount, 1)
    }

    private func signedPack(
        version: String,
        term: String,
        contentPath: String = "pack.json"
    ) throws -> (manifestData: Data, packData: Data) {
        let pack = HotVocabularyPack(
            packVersion: version,
            terms: [HotVocabularyTerm(value: term, category: "other", sourceID: "wikidata:test", weight: 80)]
        )
        let packData = try HotVocabularyCoding.encoder.encode(pack)
        var manifest = HotVocabularyManifest(
            schemaVersion: 1,
            packVersion: version,
            generatedAt: now.addingTimeInterval(-60),
            expiresAt: now.addingTimeInterval(86_400),
            minimumAppVersion: "1.4.0",
            contentSHA256: HotVocabularyVerifier.sha256Hex(packData),
            signature: "",
            contentPath: contentPath
        )
        manifest.signature = try privateKey.signature(for: manifest.signedPayload).base64EncodedString()
        return (try HotVocabularyCoding.encoder.encode(manifest), packData)
    }
}

private actor StubHotVocabularyFetcher: HotVocabularyRemoteFetching {
    private var responses: [HotVocabularyHTTPResponse]
    private var etags: [String?] = []

    init(responses: [HotVocabularyHTTPResponse]) {
        self.responses = responses
    }

    func fetch(url: URL, ifNoneMatch: String?) async throws -> HotVocabularyHTTPResponse {
        etags.append(ifNoneMatch)
        guard !responses.isEmpty else {
            throw URLError(.resourceUnavailable)
        }
        return responses.removeFirst()
    }

    func requestCount() -> Int { etags.count }
    func requestedETags() -> [String?] { etags }
}

private actor InMemoryHotVocabularyUpdateStateStore: HotVocabularyUpdateStatePersisting {
    private var state: HotVocabularyUpdateState

    init(initial: HotVocabularyUpdateState = HotVocabularyUpdateState()) {
        state = initial
    }

    func load() -> HotVocabularyUpdateState { state }
    func save(_ state: HotVocabularyUpdateState) { self.state = state }
}

private extension HotVocabularyHTTPResponse {
    static func ok(url: URL, data: Data, etag: String? = nil) -> HotVocabularyHTTPResponse {
        HotVocabularyHTTPResponse(url: url, statusCode: 200, data: data, etag: etag)
    }
}
