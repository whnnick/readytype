import Foundation
import XCTest
@testable import ReadyType

final class HotVocabularyProductionContractTests: XCTestCase {
    func testProductionConfigurationUsesExpectedEndpointAndEd25519Key() {
        XCTAssertEqual(
            HotVocabularyProductionConfiguration.manifestURL.absoluteString,
            "https://whnnick.github.io/readytype/vocabulary/v1/manifest.json"
        )
        XCTAssertEqual(HotVocabularyProductionConfiguration.publicKeyData.count, 32)
    }

    func testGeneratedArtifactPassesAppVerifierWhenProvided() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let manifestPath = environment["READYTYPE_VOCABULARY_MANIFEST"],
              let packPath = environment["READYTYPE_VOCABULARY_PACK"] else {
            throw XCTSkip("No generated production vocabulary artifact was provided.")
        }

        let verifier = try HotVocabularyProductionConfiguration.makeVerifier(
            currentAppVersion: "1.4.0"
        )
        let verified = try verifier.verify(
            manifestData: Data(contentsOf: URL(fileURLWithPath: manifestPath)),
            packData: Data(contentsOf: URL(fileURLWithPath: packPath))
        )

        XCTAssertFalse(verified.pack.terms.isEmpty)
        XCTAssertLessThanOrEqual(verified.pack.terms.count, HotVocabularyVerifier.maximumTermCount)
    }
}
