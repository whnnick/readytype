import Foundation

enum LocalSpeechModelUpdateStatus: Equatable {
    case notChecked
    case checking
    case notInstalled
    case upToDate(version: String)
    case updateAvailable(currentVersion: String, latestManifest: LocalSpeechModelManifest)
    case unableToCheck(reason: String)
}

@MainActor
protocol LocalSpeechModelManifestFetching: AnyObject {
    func latestManifest() async throws -> LocalSpeechModelManifest
}

@MainActor
protocol LocalSpeechModelUpdateChecking: AnyObject {
    func checkForUpdates() async -> LocalSpeechModelUpdateStatus
}

@MainActor
final class BundledLocalSpeechModelManifestFetcher: LocalSpeechModelManifestFetching {
    func latestManifest() async throws -> LocalSpeechModelManifest {
        LocalSpeechModelManager.defaultManifests[0]
    }
}

enum RemoteLocalSpeechModelManifestError: Error, Equatable {
    case insecureEndpoint
    case invalidResponse
    case unsupportedSchema
    case invalidModel
}

@MainActor
final class RemoteLocalSpeechModelManifestFetcher: LocalSpeechModelManifestFetching {
    static let defaultManifestURL = URL(
        string: "https://raw.githubusercontent.com/whnnick/readytype/main/distribution/manifests/high-accuracy-speech-model.json"
    )!

    private let manifestURL: URL
    private let session: URLSession

    init(
        manifestURL: URL = RemoteLocalSpeechModelManifestFetcher.defaultManifestURL,
        session: URLSession = .shared
    ) {
        self.manifestURL = manifestURL
        self.session = session
    }

    func latestManifest() async throws -> LocalSpeechModelManifest {
        guard manifestURL.scheme == "https" else {
            throw RemoteLocalSpeechModelManifestError.insecureEndpoint
        }

        var request = URLRequest(url: manifestURL)
        request.timeoutInterval = 8
        request.cachePolicy = .reloadRevalidatingCacheData

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode),
              data.count <= 64 * 1024
        else {
            throw RemoteLocalSpeechModelManifestError.invalidResponse
        }

        return try RemoteLocalSpeechModelManifestDecoder().decode(data)
    }
}

struct RemoteLocalSpeechModelManifestDecoder {
    func decode(_ data: Data) throws -> LocalSpeechModelManifest {
        let payload = try JSONDecoder().decode(RemoteManifestPayload.self, from: data)
        guard payload.schemaVersion == 1 else {
            throw RemoteLocalSpeechModelManifestError.unsupportedSchema
        }

        let model = payload.recommendedModel
        guard model.folderName == "openai_whisper-\(model.variant)",
              model.variant.range(of: #"^[A-Za-z0-9._-]+$"#, options: .regularExpression) != nil,
              !model.version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw RemoteLocalSpeechModelManifestError.invalidModel
        }

        return LocalSpeechModelManifest(
            fileName: model.folderName,
            modelName: model.variant,
            version: model.version,
            sizeDescription: model.sizeDescription
        )
    }
}

private struct RemoteManifestPayload: Decodable {
    let schemaVersion: Int
    let recommendedModel: RemoteRecommendedModel
}

private struct RemoteRecommendedModel: Decodable {
    let variant: String
    let folderName: String
    let version: String
    let sizeDescription: String?
}

@MainActor
final class LocalSpeechModelUpdateChecker: LocalSpeechModelUpdateChecking {
    private let manager: LocalSpeechModelManager
    private let manifestFetcher: LocalSpeechModelManifestFetching

    init(
        manager: LocalSpeechModelManager = LocalSpeechModelManager(),
        manifestFetcher: LocalSpeechModelManifestFetching = RemoteLocalSpeechModelManifestFetcher()
    ) {
        self.manager = manager
        self.manifestFetcher = manifestFetcher
    }

    func checkForUpdates() async -> LocalSpeechModelUpdateStatus {
        guard let installedManifest = manager.installedManifest(),
              manager.state() == .downloadedCold
        else {
            return .notInstalled
        }

        do {
            let latestManifest = try await manifestFetcher.latestManifest()
            if latestManifest.fileName != installedManifest.fileName ||
                latestManifest.version != installedManifest.version {
                return .updateAvailable(currentVersion: installedManifest.version, latestManifest: latestManifest)
            }

            return .upToDate(version: installedManifest.version)
        } catch {
            return .unableToCheck(reason: "暂时无法检查更新")
        }
    }
}
