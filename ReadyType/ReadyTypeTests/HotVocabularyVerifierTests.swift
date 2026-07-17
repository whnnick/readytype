import CryptoKit
import XCTest
@testable import ReadyType

final class HotVocabularyVerifierTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testValidSignedPackIsAccepted() throws {
        let fixture = try makeFixture()

        let verified = try fixture.verifier.verify(
            manifestData: fixture.manifestData,
            packData: fixture.packData,
            now: now
        )

        XCTAssertEqual(verified.pack.packVersion, "2026.07.17")
        XCTAssertEqual(verified.pack.terms.map(\.value), ["ReadyType", "流浪地球三"])
    }

    func testModifiedPackIsRejected() throws {
        let fixture = try makeFixture()
        let modifiedPack = HotVocabularyPack(
            packVersion: fixture.pack.packVersion,
            terms: fixture.pack.terms + [HotVocabularyTerm(value: "未签名词条", category: "other", sourceID: "test")]
        )
        let modifiedData = try HotVocabularyCoding.encoder.encode(modifiedPack)

        XCTAssertThrowsError(
            try fixture.verifier.verify(
                manifestData: fixture.manifestData,
                packData: modifiedData,
                now: now
            )
        ) { error in
            XCTAssertEqual(error as? HotVocabularyVerificationError, .contentHashMismatch)
        }
    }

    func testManifestMetadataCannotBeChangedAfterSigning() throws {
        let fixture = try makeFixture()
        var changedManifest = fixture.manifest
        changedManifest.minimumAppVersion = "0.1.0"
        let changedData = try HotVocabularyCoding.encoder.encode(changedManifest)

        XCTAssertThrowsError(
            try fixture.verifier.verify(
                manifestData: changedData,
                packData: fixture.packData,
                now: now
            )
        ) { error in
            XCTAssertEqual(error as? HotVocabularyVerificationError, .invalidSignature)
        }
    }

    func testExpiredPackIsRejected() throws {
        let fixture = try makeFixture(expiresAt: now.addingTimeInterval(-1))

        XCTAssertThrowsError(
            try fixture.verifier.verify(
                manifestData: fixture.manifestData,
                packData: fixture.packData,
                now: now
            )
        ) { error in
            XCTAssertEqual(error as? HotVocabularyVerificationError, .expired)
        }
    }

    func testPackRequiringNewerAppIsRejected() throws {
        let fixture = try makeFixture(minimumAppVersion: "2.0.0")

        XCTAssertThrowsError(
            try fixture.verifier.verify(
                manifestData: fixture.manifestData,
                packData: fixture.packData,
                now: now
            )
        ) { error in
            XCTAssertEqual(error as? HotVocabularyVerificationError, .unsupportedAppVersion)
        }
    }

    func testDuplicateTermsAreRejectedAfterNormalization() throws {
        let pack = HotVocabularyPack(
            packVersion: "2026.07.17",
            terms: [
                HotVocabularyTerm(value: "ReadyType", category: "product", sourceID: "wikidata:Q1"),
                HotVocabularyTerm(value: "ready type", category: "product", sourceID: "wikidata:Q1")
            ]
        )
        let fixture = try makeFixture(pack: pack)

        XCTAssertThrowsError(
            try fixture.verifier.verify(
                manifestData: fixture.manifestData,
                packData: fixture.packData,
                now: now
            )
        ) { error in
            XCTAssertEqual(error as? HotVocabularyVerificationError, .duplicateTerm)
        }
    }

    func testUnsafePackVersionIsRejected() throws {
        let pack = HotVocabularyPack(
            packVersion: "..",
            terms: [HotVocabularyTerm(value: "ReadyType", category: "product", sourceID: "wikidata:Q1")]
        )
        let fixture = try makeFixture(pack: pack)

        XCTAssertThrowsError(
            try fixture.verifier.verify(
                manifestData: fixture.manifestData,
                packData: fixture.packData,
                now: now
            )
        ) { error in
            XCTAssertEqual(error as? HotVocabularyVerificationError, .invalidManifest)
        }
    }

    private func makeFixture(
        pack: HotVocabularyPack? = nil,
        expiresAt: Date? = nil,
        minimumAppVersion: String = "1.0.0"
    ) throws -> SignedHotVocabularyFixture {
        let privateKey = Curve25519.Signing.PrivateKey()
        let pack = pack ?? HotVocabularyPack(
            packVersion: "2026.07.17",
            terms: [
                HotVocabularyTerm(
                    value: "ReadyType",
                    aliases: ["Ready Type"],
                    category: "product",
                    scopes: [.all],
                    sourceID: "wikidata:Q1",
                    weight: 90
                ),
                HotVocabularyTerm(
                    value: "流浪地球三",
                    category: "movie",
                    scopes: [.chat],
                    sourceID: "wikidata:Q2",
                    weight: 80
                )
            ]
        )
        let packData = try HotVocabularyCoding.encoder.encode(pack)
        var manifest = HotVocabularyManifest(
            schemaVersion: 1,
            packVersion: pack.packVersion,
            generatedAt: now.addingTimeInterval(-60),
            expiresAt: expiresAt ?? now.addingTimeInterval(86_400),
            minimumAppVersion: minimumAppVersion,
            contentSHA256: HotVocabularyVerifier.sha256Hex(packData),
            signature: ""
        )
        manifest.signature = try privateKey.signature(for: manifest.signedPayload).base64EncodedString()
        let manifestData = try HotVocabularyCoding.encoder.encode(manifest)
        let verifier = try HotVocabularyVerifier(
            publicKeyData: privateKey.publicKey.rawRepresentation,
            currentAppVersion: "1.4.0"
        )
        return SignedHotVocabularyFixture(
            verifier: verifier,
            manifest: manifest,
            manifestData: manifestData,
            pack: pack,
            packData: packData
        )
    }
}

private struct SignedHotVocabularyFixture {
    let verifier: HotVocabularyVerifier
    let manifest: HotVocabularyManifest
    let manifestData: Data
    let pack: HotVocabularyPack
    let packData: Data
}
