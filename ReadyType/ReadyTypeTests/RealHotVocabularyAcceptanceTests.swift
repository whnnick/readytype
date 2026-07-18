import Foundation
import XCTest
@testable import ReadyType

final class RealHotVocabularyAcceptanceTests: XCTestCase {
    @MainActor
    func testProductionPackDownloadsVerifiesAndLoads() async throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["RUN_HOT_VOCABULARY"] == "1",
            "Set RUN_HOT_VOCABULARY=1 to verify the live signed vocabulary pack."
        )

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReadyTypeRealHotVocabularyAcceptance-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let verifier = try HotVocabularyProductionConfiguration.makeVerifier(
            currentAppVersion: "1.4.0"
        )
        let store = HotVocabularyStore(rootDirectory: directory, verifier: verifier)
        let updater = HotVocabularyUpdater(
            manifestURL: HotVocabularyProductionConfiguration.manifestURL,
            store: store,
            stateStore: AcceptanceVocabularyUpdateStateStore()
        )
        let coordinator = HotVocabularyCoordinator(store: store, updater: updater)

        await coordinator.update(force: true)

        guard case .ready = coordinator.status else {
            return XCTFail("Live vocabulary did not become ready: \(coordinator.status)")
        }
        XCTAssertFalse(try XCTUnwrap(coordinator.activePack).pack.terms.isEmpty)
    }
}

private actor AcceptanceVocabularyUpdateStateStore: HotVocabularyUpdateStatePersisting {
    private var state = HotVocabularyUpdateState()

    func load() -> HotVocabularyUpdateState { state }
    func save(_ state: HotVocabularyUpdateState) { self.state = state }
}
