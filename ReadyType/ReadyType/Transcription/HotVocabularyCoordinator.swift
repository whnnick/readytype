import Foundation

enum HotVocabularyStatus: Equatable {
    case notDownloaded
    case checking(currentVersion: String?)
    case ready(version: String, generatedAt: Date)
    case unavailable(currentVersion: String?)

    var currentVersion: String? {
        switch self {
        case .notDownloaded:
            return nil
        case .checking(let version), .unavailable(let version):
            return version
        case .ready(let version, _):
            return version
        }
    }
}

@MainActor
final class HotVocabularyCoordinator: ObservableObject {
    @Published private(set) var status: HotVocabularyStatus = .notDownloaded
    private(set) var activePack: VerifiedHotVocabularyPack?

    private let store: HotVocabularyStore
    private let updater: HotVocabularyUpdater

    init(store: HotVocabularyStore, updater: HotVocabularyUpdater) {
        self.store = store
        self.updater = updater
    }

    func loadCachedPack(now: Date = Date()) {
        activePack = try? store.loadActive(now: now)
        status = activePack.map(Self.readyStatus) ?? .notDownloaded
    }

    func update(force: Bool = false, now: Date = Date()) async {
        if case .checking = status {
            return
        }
        let previousVersion = activePack?.manifest.packVersion
        status = .checking(currentVersion: previousVersion)

        switch await updater.update(force: force, now: now) {
        case .installed, .notModified, .skippedRecentCheck:
            activePack = try? store.loadActive(now: now)
            status = activePack.map(Self.readyStatus) ?? .notDownloaded
        case .failed:
            status = .unavailable(currentVersion: previousVersion)
        }
    }

    private static func readyStatus(_ pack: VerifiedHotVocabularyPack) -> HotVocabularyStatus {
        .ready(
            version: pack.manifest.packVersion,
            generatedAt: pack.manifest.generatedAt
        )
    }
}
