import Foundation

enum LocalSpeechModelUpdateStatus: Equatable {
    case notChecked
    case checking
    case notInstalled
    case upToDate(version: String)
    case updateAvailable(currentVersion: String, latestVersion: String, sizeDescription: String?)
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

@MainActor
final class LocalSpeechModelUpdateChecker: LocalSpeechModelUpdateChecking {
    private let manager: LocalSpeechModelManager
    private let manifestFetcher: LocalSpeechModelManifestFetching

    init(
        manager: LocalSpeechModelManager = LocalSpeechModelManager(),
        manifestFetcher: LocalSpeechModelManifestFetching = BundledLocalSpeechModelManifestFetcher()
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
                return .updateAvailable(
                    currentVersion: installedManifest.version,
                    latestVersion: latestManifest.version,
                    sizeDescription: latestManifest.sizeDescription
                )
            }

            return .upToDate(version: installedManifest.version)
        } catch {
            return .unableToCheck(reason: "暂时无法检查更新")
        }
    }
}
