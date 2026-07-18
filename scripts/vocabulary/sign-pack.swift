import CryptoKit
import Foundation

struct Pack: Codable {
    var packVersion: String
    var terms: [Term]
}

struct Term: Codable {
    var value: String
    var aliases: [String]
    var category: String
    var scopes: [String]
    var sourceID: String
    var weight: Double
    var expiresAt: Date?
}

struct Manifest: Codable {
    var schemaVersion: Int
    var packVersion: String
    var generatedAt: Date
    var expiresAt: Date
    var minimumAppVersion: String
    var contentSHA256: String
    var signature: String
    var contentPath: String

    var signedPayload: Data {
        let fields = [
            "schemaVersion=\(schemaVersion)",
            "packVersion=\(packVersion)",
            "generatedAt=\(timestamp(generatedAt))",
            "expiresAt=\(timestamp(expiresAt))",
            "minimumAppVersion=\(minimumAppVersion)",
            "contentPath=\(contentPath)",
            "contentSHA256=\(contentSHA256)"
        ]
        return Data((fields.joined(separator: "\n") + "\n").utf8)
    }
}

func timestamp(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    return formatter.string(from: date)
}

func coder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    encoder.dateEncodingStrategy = .iso8601
    return encoder
}

guard CommandLine.arguments.count == 4 else {
    fputs("Usage: sign-pack.swift INPUT_JSON OUTPUT_DIRECTORY MINIMUM_APP_VERSION\n", stderr)
    exit(2)
}
guard let privateKeyValue = ProcessInfo.processInfo.environment["READYTYPE_VOCABULARY_SIGNING_PRIVATE_KEY"],
      let privateKeyData = Data(base64Encoded: privateKeyValue),
      privateKeyData.count == 32 else {
    fputs("READYTYPE_VOCABULARY_SIGNING_PRIVATE_KEY must contain a 32-byte Base64 Ed25519 key.\n", stderr)
    exit(2)
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
let minimumAppVersion = CommandLine.arguments[3]
let decoder = JSONDecoder()
decoder.dateDecodingStrategy = .iso8601
let pack = try decoder.decode(Pack.self, from: Data(contentsOf: inputURL))
guard !pack.terms.isEmpty, pack.terms.count <= 5_000 else {
    throw NSError(domain: "ReadyTypeVocabulary", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid term count"])
}

let packData = try coder().encode(pack)
let versionFormatter = DateFormatter()
versionFormatter.locale = Locale(identifier: "en_US_POSIX")
versionFormatter.timeZone = TimeZone(secondsFromGMT: 0)
versionFormatter.dateFormat = "yyyy.MM.dd"
guard let sourceDay = versionFormatter.date(from: pack.packVersion) else {
    throw NSError(domain: "ReadyTypeVocabulary", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid pack version"])
}
var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(secondsFromGMT: 0)!
let generatedAt = calendar.date(byAdding: .day, value: 1, to: sourceDay)!
let expiresAt = calendar.date(byAdding: .day, value: 15, to: sourceDay)!
let hash = SHA256.hash(data: packData).map { String(format: "%02x", $0) }.joined()
let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: privateKeyData)
var manifest = Manifest(
    schemaVersion: 1,
    packVersion: pack.packVersion,
    generatedAt: generatedAt,
    expiresAt: expiresAt,
    minimumAppVersion: minimumAppVersion,
    contentSHA256: hash,
    signature: "",
    contentPath: "pack.json"
)
manifest.signature = try privateKey.signature(for: manifest.signedPayload).base64EncodedString()

try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
try packData.write(to: outputURL.appendingPathComponent("pack.json"), options: .atomic)
try coder().encode(manifest).write(to: outputURL.appendingPathComponent("manifest.json"), options: .atomic)
