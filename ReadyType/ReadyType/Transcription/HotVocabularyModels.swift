import Foundation

struct HotVocabularyManifest: Codable, Equatable {
    var schemaVersion: Int
    var packVersion: String
    var generatedAt: Date
    var expiresAt: Date
    var minimumAppVersion: String
    var contentSHA256: String
    var signature: String
    var contentPath: String = "pack.json"

    var signedPayload: Data {
        let fields = [
            "schemaVersion=\(schemaVersion)",
            "packVersion=\(packVersion)",
            "generatedAt=\(HotVocabularyCoding.timestamp(generatedAt))",
            "expiresAt=\(HotVocabularyCoding.timestamp(expiresAt))",
            "minimumAppVersion=\(minimumAppVersion)",
            "contentPath=\(contentPath)",
            "contentSHA256=\(contentSHA256)"
        ]
        return Data((fields.joined(separator: "\n") + "\n").utf8)
    }
}

struct HotVocabularyPack: Codable, Equatable {
    var packVersion: String
    var terms: [HotVocabularyTerm]
}

struct HotVocabularyTerm: Codable, Equatable {
    var value: String
    var aliases: [String]
    var category: String
    var scopes: [UserVocabularyScope]
    var sourceID: String
    var weight: Double
    var expiresAt: Date?

    init(
        value: String,
        aliases: [String] = [],
        category: String,
        scopes: [UserVocabularyScope] = [.all],
        sourceID: String,
        weight: Double = 0,
        expiresAt: Date? = nil
    ) {
        self.value = value
        self.aliases = aliases
        self.category = category
        self.scopes = scopes
        self.sourceID = sourceID
        self.weight = weight
        self.expiresAt = expiresAt
    }
}

struct VerifiedHotVocabularyPack: Equatable {
    var manifest: HotVocabularyManifest
    var pack: HotVocabularyPack
}

enum HotVocabularyCoding {
    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    static func timestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }
}
