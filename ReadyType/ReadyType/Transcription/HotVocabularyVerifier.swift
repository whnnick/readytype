import CryptoKit
import Foundation

enum HotVocabularyVerificationError: Error, Equatable {
    case unsupportedSchema
    case invalidManifest
    case contentTooLarge
    case contentHashMismatch
    case invalidSignature
    case expired
    case unsupportedAppVersion
    case invalidPack
    case invalidTerm
    case duplicateTerm
}

struct HotVocabularyVerifier {
    static let supportedSchemaVersion = 1
    static let maximumManifestBytes = 64 * 1024
    static let maximumContentBytes = 512 * 1024
    static let maximumTermCount = 5_000

    private let publicKey: Curve25519.Signing.PublicKey
    private let currentAppVersion: SemanticVersion

    init(publicKeyData: Data, currentAppVersion: String) throws {
        self.publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData)
        guard let version = SemanticVersion(currentAppVersion) else {
            throw HotVocabularyVerificationError.invalidManifest
        }
        self.currentAppVersion = version
    }

    func verify(
        manifestData: Data,
        packData: Data,
        now: Date = Date()
    ) throws -> VerifiedHotVocabularyPack {
        guard manifestData.count <= Self.maximumManifestBytes else {
            throw HotVocabularyVerificationError.invalidManifest
        }
        let manifest: HotVocabularyManifest
        do {
            manifest = try HotVocabularyCoding.decoder.decode(HotVocabularyManifest.self, from: manifestData)
        } catch {
            throw HotVocabularyVerificationError.invalidManifest
        }

        guard manifest.schemaVersion == Self.supportedSchemaVersion else {
            throw HotVocabularyVerificationError.unsupportedSchema
        }
        guard Self.isSafeIdentifier(manifest.packVersion),
              Self.isSafeContentPath(manifest.contentPath),
              Self.isSHA256(manifest.contentSHA256),
              manifest.generatedAt <= manifest.expiresAt,
              manifest.generatedAt <= now.addingTimeInterval(86_400),
              let minimumAppVersion = SemanticVersion(manifest.minimumAppVersion),
              let signature = Data(base64Encoded: manifest.signature),
              signature.count == 64
        else {
            throw HotVocabularyVerificationError.invalidManifest
        }
        guard packData.count <= Self.maximumContentBytes else {
            throw HotVocabularyVerificationError.contentTooLarge
        }
        guard Self.sha256Hex(packData) == manifest.contentSHA256.lowercased() else {
            throw HotVocabularyVerificationError.contentHashMismatch
        }
        guard publicKey.isValidSignature(signature, for: manifest.signedPayload) else {
            throw HotVocabularyVerificationError.invalidSignature
        }
        guard now < manifest.expiresAt else {
            throw HotVocabularyVerificationError.expired
        }
        guard currentAppVersion >= minimumAppVersion else {
            throw HotVocabularyVerificationError.unsupportedAppVersion
        }

        let pack: HotVocabularyPack
        do {
            pack = try HotVocabularyCoding.decoder.decode(HotVocabularyPack.self, from: packData)
        } catch {
            throw HotVocabularyVerificationError.invalidPack
        }
        guard pack.packVersion == manifest.packVersion,
              !pack.terms.isEmpty,
              pack.terms.count <= Self.maximumTermCount
        else {
            throw HotVocabularyVerificationError.invalidPack
        }

        var termKeys: Set<String> = []
        for term in pack.terms {
            try validate(term: term)
            guard termKeys.insert(term.value.normalizedSmartTermKey).inserted else {
                throw HotVocabularyVerificationError.duplicateTerm
            }
        }

        return VerifiedHotVocabularyPack(manifest: manifest, pack: pack)
    }

    static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private func validate(term: HotVocabularyTerm) throws {
        let value = term.value.trimmingCharacters(in: .whitespacesAndNewlines)
        let category = term.category.trimmingCharacters(in: .whitespacesAndNewlines)
        let sourceID = term.sourceID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty,
              !value.normalizedSmartTermKey.isEmpty,
              value.count <= 80,
              term.aliases.count <= 8,
              term.aliases.allSatisfy({ alias in
                  let clean = alias.trimmingCharacters(in: .whitespacesAndNewlines)
                  return !clean.isEmpty && clean.count <= 80
              }),
              !category.isEmpty,
              category.count <= 32,
              !sourceID.isEmpty,
              sourceID.count <= 128,
              !term.scopes.isEmpty,
              term.weight.isFinite,
              (0...100).contains(term.weight)
        else {
            throw HotVocabularyVerificationError.invalidTerm
        }
    }

    private static func isSafeIdentifier(_ value: String) -> Bool {
        ![".", ".."].contains(value) &&
            value.count <= 64 &&
            value.range(of: #"^[A-Za-z0-9._-]+$"#, options: .regularExpression) != nil
    }

    private static func isSHA256(_ value: String) -> Bool {
        value.range(of: #"^[A-Fa-f0-9]{64}$"#, options: .regularExpression) != nil
    }

    static func isSafeContentPath(_ value: String) -> Bool {
        ![".", ".."].contains(value) &&
            value.count <= 128 &&
            value.range(of: #"^[A-Za-z0-9][A-Za-z0-9._-]*\.json$"#, options: .regularExpression) != nil
    }
}

private struct SemanticVersion: Comparable {
    let components: [Int]

    init?(_ value: String) {
        let core = value.split(separator: "-", maxSplits: 1).first.map(String.init) ?? value
        let pieces = core.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...3).contains(pieces.count),
              pieces.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }),
              let parsed = Optional(pieces.compactMap { Int($0) }),
              parsed.count == pieces.count
        else {
            return nil
        }
        self.components = parsed + Array(repeating: 0, count: 3 - parsed.count)
    }

    static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        lhs.components.lexicographicallyPrecedes(rhs.components)
    }
}
