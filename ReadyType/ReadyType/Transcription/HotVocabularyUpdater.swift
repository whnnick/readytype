import Foundation

struct HotVocabularyHTTPResponse: Sendable {
    var url: URL
    var statusCode: Int
    var data: Data?
    var etag: String?
}

protocol HotVocabularyRemoteFetching: Sendable {
    func fetch(url: URL, ifNoneMatch: String?) async throws -> HotVocabularyHTTPResponse
}

struct URLSessionHotVocabularyFetcher: HotVocabularyRemoteFetching {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetch(url: URL, ifNoneMatch: String?) async throws -> HotVocabularyHTTPResponse {
        guard url.scheme?.lowercased() == "https" else {
            throw URLError(.secureConnectionFailed)
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.cachePolicy = .reloadRevalidatingCacheData
        if let ifNoneMatch, !ifNoneMatch.isEmpty {
            request.setValue(ifNoneMatch, forHTTPHeaderField: "If-None-Match")
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              let finalURL = httpResponse.url else {
            throw URLError(.badServerResponse)
        }
        return HotVocabularyHTTPResponse(
            url: finalURL,
            statusCode: httpResponse.statusCode,
            data: httpResponse.statusCode == 304 ? nil : data,
            etag: httpResponse.value(forHTTPHeaderField: "ETag")
        )
    }
}

struct HotVocabularyUpdateState: Codable, Equatable, Sendable {
    var lastCheckedAt: Date?
    var etag: String?

    init(lastCheckedAt: Date? = nil, etag: String? = nil) {
        self.lastCheckedAt = lastCheckedAt
        self.etag = etag
    }
}

protocol HotVocabularyUpdateStatePersisting: Sendable {
    func load() async -> HotVocabularyUpdateState
    func save(_ state: HotVocabularyUpdateState) async
}

actor FileHotVocabularyUpdateStateStore: HotVocabularyUpdateStatePersisting {
    private let fileURL: URL

    init(fileURL: URL = FileHotVocabularyUpdateStateStore.defaultFileURL()) {
        self.fileURL = fileURL
    }

    func load() -> HotVocabularyUpdateState {
        guard let data = try? Data(contentsOf: fileURL),
              let state = try? HotVocabularyCoding.decoder.decode(HotVocabularyUpdateState.self, from: data)
        else {
            return HotVocabularyUpdateState()
        }
        return state
    }

    func save(_ state: HotVocabularyUpdateState) {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try HotVocabularyCoding.encoder.encode(state).write(to: fileURL, options: .atomic)
        } catch {
            return
        }
    }

    static func defaultFileURL() -> URL {
        HotVocabularyStore.defaultRootDirectory().appendingPathComponent("update-state.json")
    }
}

enum HotVocabularyUpdateFailure: Equatable, Sendable {
    case network
    case invalidResponse
    case verification
    case storage
}

enum HotVocabularyUpdateResult: Equatable, Sendable {
    case skippedRecentCheck
    case notModified(version: String?)
    case installed(version: String)
    case failed(HotVocabularyUpdateFailure)
}

actor HotVocabularyUpdater {
    static let automaticCheckInterval: TimeInterval = 24 * 60 * 60

    private let manifestURL: URL
    private let fetcher: any HotVocabularyRemoteFetching
    private let store: HotVocabularyStore
    private let stateStore: any HotVocabularyUpdateStatePersisting

    init(
        manifestURL: URL,
        fetcher: any HotVocabularyRemoteFetching = URLSessionHotVocabularyFetcher(),
        store: HotVocabularyStore,
        stateStore: any HotVocabularyUpdateStatePersisting = FileHotVocabularyUpdateStateStore()
    ) {
        self.manifestURL = manifestURL
        self.fetcher = fetcher
        self.store = store
        self.stateStore = stateStore
    }

    func update(force: Bool = false, now: Date = Date()) async -> HotVocabularyUpdateResult {
        var state = await stateStore.load()
        if !force,
           let lastCheckedAt = state.lastCheckedAt,
           now.timeIntervalSince(lastCheckedAt) >= 0,
           now.timeIntervalSince(lastCheckedAt) < Self.automaticCheckInterval {
            return .skippedRecentCheck
        }

        guard manifestURL.scheme?.lowercased() == "https" else {
            return await finish(.failed(.invalidResponse), state: state, now: now)
        }

        do {
            var manifestResponse = try await fetcher.fetch(url: manifestURL, ifNoneMatch: state.etag)
            guard Self.hasSameOrigin(manifestResponse.url, manifestURL) else {
                return await finish(.failed(.invalidResponse), state: state, now: now)
            }

            if manifestResponse.statusCode == 304 {
                if let activePack = try? store.loadActive(now: now) {
                    return await finish(
                        .notModified(version: activePack.manifest.packVersion),
                        state: state,
                        now: now
                    )
                }
                manifestResponse = try await fetcher.fetch(url: manifestURL, ifNoneMatch: nil)
                guard Self.hasSameOrigin(manifestResponse.url, manifestURL) else {
                    return await finish(.failed(.invalidResponse), state: state, now: now)
                }
            }

            guard manifestResponse.statusCode == 200,
                  let manifestData = manifestResponse.data,
                  manifestData.count <= HotVocabularyVerifier.maximumManifestBytes,
                  let manifest = try? HotVocabularyCoding.decoder.decode(
                      HotVocabularyManifest.self,
                      from: manifestData
                  ),
                  HotVocabularyVerifier.isSafeContentPath(manifest.contentPath)
            else {
                return await finish(.failed(.invalidResponse), state: state, now: now)
            }

            let packURL = manifestURL.deletingLastPathComponent()
                .appendingPathComponent(manifest.contentPath, isDirectory: false)
            guard Self.hasSameOrigin(packURL, manifestURL) else {
                return await finish(.failed(.invalidResponse), state: state, now: now)
            }

            let packResponse = try await fetcher.fetch(url: packURL, ifNoneMatch: nil)
            guard packResponse.statusCode == 200,
                  Self.hasSameOrigin(packResponse.url, manifestURL),
                  let packData = packResponse.data,
                  packData.count <= HotVocabularyVerifier.maximumContentBytes
            else {
                return await finish(.failed(.invalidResponse), state: state, now: now)
            }

            let installed: VerifiedHotVocabularyPack
            do {
                installed = try store.install(
                    manifestData: manifestData,
                    packData: packData,
                    now: now
                )
            } catch is HotVocabularyVerificationError {
                return await finish(.failed(.verification), state: state, now: now)
            } catch {
                return await finish(.failed(.storage), state: state, now: now)
            }

            state.etag = manifestResponse.etag
            return await finish(.installed(version: installed.manifest.packVersion), state: state, now: now)
        } catch {
            return await finish(.failed(.network), state: state, now: now)
        }
    }

    private func finish(
        _ result: HotVocabularyUpdateResult,
        state: HotVocabularyUpdateState,
        now: Date
    ) async -> HotVocabularyUpdateResult {
        var updatedState = state
        updatedState.lastCheckedAt = now
        await stateStore.save(updatedState)
        return result
    }

    private static func hasSameOrigin(_ lhs: URL, _ rhs: URL) -> Bool {
        lhs.scheme?.lowercased() == "https" &&
            lhs.scheme?.lowercased() == rhs.scheme?.lowercased() &&
            lhs.host?.lowercased() == rhs.host?.lowercased() &&
            lhs.port == rhs.port
    }
}
