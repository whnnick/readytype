import CryptoKit
import Foundation

enum LocalSpeechModelState: Equatable {
    case notInstalled
    case downloading(progress: Double)
    case downloadedCold
    case warming
    case warm
    case failed(reason: String)
}

struct LocalSpeechModelManifest: Equatable {
    let fileName: String
    let version: String
    let expectedChecksum: LocalSpeechModelChecksum?
    let downloadURL: URL?
    let sizeDescription: String?

    init(
        fileName: String,
        version: String? = nil,
        expectedSHA256: String? = nil,
        expectedSHA1: String? = nil,
        downloadURL: URL? = nil,
        sizeDescription: String? = nil
    ) {
        self.fileName = fileName
        self.version = version ?? Self.derivedVersion(from: fileName)
        if let expectedSHA256 {
            self.expectedChecksum = LocalSpeechModelChecksum(algorithm: .sha256, value: expectedSHA256)
        } else if let expectedSHA1 {
            self.expectedChecksum = LocalSpeechModelChecksum(algorithm: .sha1, value: expectedSHA1)
        } else {
            self.expectedChecksum = nil
        }
        self.downloadURL = downloadURL
        self.sizeDescription = sizeDescription
    }

    private static func derivedVersion(from fileName: String) -> String {
        let pattern = #"v(\d{8})"#
        let range = NSRange(fileName.startIndex..<fileName.endIndex, in: fileName)
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: fileName, range: range),
              let versionRange = Range(match.range(at: 1), in: fileName)
        else {
            return fileName
        }

        let rawVersion = String(fileName[versionRange])
        guard rawVersion.count == 8 else {
            return rawVersion
        }

        let year = rawVersion.prefix(4)
        let monthStart = rawVersion.index(rawVersion.startIndex, offsetBy: 4)
        let dayStart = rawVersion.index(rawVersion.startIndex, offsetBy: 6)
        let month = rawVersion[monthStart..<dayStart]
        let day = rawVersion[dayStart..<rawVersion.endIndex]
        return "\(year)-\(month)-\(day)"
    }
}

struct LocalSpeechModelChecksum: Equatable {
    let algorithm: LocalSpeechModelChecksumAlgorithm
    let value: String

    init(algorithm: LocalSpeechModelChecksumAlgorithm, value: String) {
        self.algorithm = algorithm
        self.value = value.lowercased()
    }
}

enum LocalSpeechModelChecksumAlgorithm: String, Equatable {
    case sha1
    case sha256
}

final class LocalSpeechModelManager {
    static let defaultWhisperKitModelName = "large-v3-v20240930_626MB"
    static let defaultWhisperKitModelFolderName = "openai_whisper-large-v3-v20240930_626MB"

    static let defaultManifests = [
        LocalSpeechModelManifest(
            fileName: defaultWhisperKitModelFolderName,
            version: "2024-09-30",
            sizeDescription: "约 626 MiB"
        )
    ]

    let modelsDirectory: URL

    private let manifests: [LocalSpeechModelManifest]
    private let fileManager: FileManager

    init(
        modelsDirectory: URL = LocalSpeechModelManager.defaultModelsDirectory(),
        manifests: [LocalSpeechModelManifest] = LocalSpeechModelManager.defaultManifests,
        fileManager: FileManager = .default
    ) {
        self.modelsDirectory = modelsDirectory
        self.manifests = manifests
        self.fileManager = fileManager
    }

    func state() -> LocalSpeechModelState {
        guard let installedManifest = installedManifest(),
              let modelURL = modelURL(for: installedManifest)
        else {
            return .notInstalled
        }

        if let expectedChecksum = installedManifest.expectedChecksum,
           checksumHex(for: modelURL, algorithm: expectedChecksum.algorithm) != expectedChecksum.value {
            return .failed(reason: "模型校验失败：\(installedManifest.fileName)")
        }

        guard isUsableModel(at: modelURL) else {
            return .failed(reason: "模型校验失败：\(installedManifest.fileName)")
        }

        return .downloadedCold
    }

    func installedModelURL() -> URL? {
        guard let manifest = installedManifest(),
              state() == .downloadedCold
        else {
            return nil
        }

        return modelURL(for: manifest)
    }

    func defaultDownloadManifest() -> LocalSpeechModelManifest? {
        manifests.first
    }

    func destinationURL(for manifest: LocalSpeechModelManifest) -> URL {
        modelsDirectory.appendingPathComponent(manifest.fileName)
    }

    func deleteInstalledModels() throws {
        for manifest in manifests {
            let url = modelsDirectory.appendingPathComponent(manifest.fileName)
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
        }
    }

    func installedManifest() -> LocalSpeechModelManifest? {
        manifests.first { manifest in
            let url = modelsDirectory.appendingPathComponent(manifest.fileName)
            return fileManager.fileExists(atPath: url.path)
        }
    }

    private func modelURL(for manifest: LocalSpeechModelManifest) -> URL? {
        let url = modelsDirectory.appendingPathComponent(manifest.fileName)
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }

        return url
    }

    private func isUsableModel(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return false
        }

        guard isDirectory.boolValue else {
            return true
        }

        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return false
        }

        for case let child as URL in enumerator {
            if (try? child.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true {
                return true
            }
        }

        return false
    }

    private func checksumHex(for url: URL, algorithm: LocalSpeechModelChecksumAlgorithm) -> String? {
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }

        switch algorithm {
        case .sha1:
            return Insecure.SHA1.hash(data: data)
                .map { String(format: "%02x", $0) }
                .joined()
        case .sha256:
            return sha256Hex(for: data)
        }
    }

    private func sha256Hex(for data: Data) -> String {
        return SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private static func defaultModelsDirectory() -> URL {
        let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")

        return applicationSupport.appendingPathComponent("ReadyType/Models", isDirectory: true)
    }

    static func defaultModelsDirectoryPath() -> String {
        defaultModelsDirectory().path
    }
}
