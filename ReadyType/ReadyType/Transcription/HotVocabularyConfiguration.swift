import Foundation

enum HotVocabularyProductionConfiguration {
    static let manifestURL = URL(
        string: "https://whnnick.github.io/readytype/vocabulary/v1/manifest.json"
    )!

    static let publicKeyData: Data = {
        guard let data = Data(base64Encoded: "uf/vQ3DXIVbd/QMVdyYHsFh55xbBAUNaK4K1YpVIchY="),
              data.count == 32 else {
            preconditionFailure("Invalid hot vocabulary public key")
        }
        return data
    }()

    static func makeVerifier(currentAppVersion: String) throws -> HotVocabularyVerifier {
        try HotVocabularyVerifier(
            publicKeyData: publicKeyData,
            currentAppVersion: currentAppVersion
        )
    }
}
