import Foundation

enum HotVocabularyStoreError: Error {
    case invalidPointer
    case noValidPack
}

final class HotVocabularyStore {
    private struct Pointer: Codable, Equatable {
        var directoryName: String
        var packVersion: String
    }

    private let rootDirectory: URL
    private let verifier: HotVocabularyVerifier
    private let fileManager: FileManager

    private var versionsDirectory: URL {
        rootDirectory.appendingPathComponent("versions", isDirectory: true)
    }

    private var activePointerURL: URL {
        rootDirectory.appendingPathComponent("active.json")
    }

    private var previousPointerURL: URL {
        rootDirectory.appendingPathComponent("previous.json")
    }

    init(
        rootDirectory: URL = HotVocabularyStore.defaultRootDirectory(),
        verifier: HotVocabularyVerifier,
        fileManager: FileManager = .default
    ) {
        self.rootDirectory = rootDirectory
        self.verifier = verifier
        self.fileManager = fileManager
    }

    @discardableResult
    func install(
        manifestData: Data,
        packData: Data,
        now: Date = Date()
    ) throws -> VerifiedHotVocabularyPack {
        let verified = try verifier.verify(
            manifestData: manifestData,
            packData: packData,
            now: now
        )
        try fileManager.createDirectory(at: versionsDirectory, withIntermediateDirectories: true)

        let hashPrefix = String(verified.manifest.contentSHA256.prefix(12)).lowercased()
        let baseName = "\(verified.manifest.packVersion)-\(hashPrefix)"
        let directoryName = try persistImmutableVersion(
            baseName: baseName,
            manifestData: manifestData,
            packData: packData,
            now: now
        )
        let newPointer = Pointer(
            directoryName: directoryName,
            packVersion: verified.manifest.packVersion
        )

        if let currentPointer = try? readPointer(at: activePointerURL),
           currentPointer != newPointer {
            try writePointer(currentPointer, to: previousPointerURL)
        }
        try writePointer(newPointer, to: activePointerURL)
        return verified
    }

    func loadActive(now: Date = Date()) throws -> VerifiedHotVocabularyPack? {
        guard fileManager.fileExists(atPath: activePointerURL.path) else {
            return nil
        }

        if let active = try? load(pointerAt: activePointerURL, now: now) {
            return active
        }
        if fileManager.fileExists(atPath: previousPointerURL.path),
           let previous = try? load(pointerAt: previousPointerURL, now: now) {
            return previous
        }
        throw HotVocabularyStoreError.noValidPack
    }

    func activePackFileURL() throws -> URL? {
        guard fileManager.fileExists(atPath: activePointerURL.path) else {
            return nil
        }
        let pointer = try readPointer(at: activePointerURL)
        return versionDirectory(for: pointer).appendingPathComponent("pack.json")
    }

    static func defaultRootDirectory() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ReadyType", isDirectory: true)
            .appendingPathComponent("HotVocabulary", isDirectory: true)
    }

    private func persistImmutableVersion(
        baseName: String,
        manifestData: Data,
        packData: Data,
        now: Date
    ) throws -> String {
        let baseURL = versionsDirectory.appendingPathComponent(baseName, isDirectory: true)
        if fileManager.fileExists(atPath: baseURL.path),
           (try? verifyVersion(at: baseURL, now: now)) != nil {
            return baseName
        }

        let finalName = fileManager.fileExists(atPath: baseURL.path)
            ? "\(baseName)-\(UUID().uuidString.lowercased())"
            : baseName
        let finalURL = versionsDirectory.appendingPathComponent(finalName, isDirectory: true)
        let stagingURL = versionsDirectory.appendingPathComponent(".staging-\(UUID().uuidString)", isDirectory: true)

        do {
            try fileManager.createDirectory(at: stagingURL, withIntermediateDirectories: false)
            try manifestData.write(to: stagingURL.appendingPathComponent("manifest.json"), options: .atomic)
            try packData.write(to: stagingURL.appendingPathComponent("pack.json"), options: .atomic)
            _ = try verifyVersion(at: stagingURL, now: now)
            try fileManager.moveItem(at: stagingURL, to: finalURL)
            return finalName
        } catch {
            try? fileManager.removeItem(at: stagingURL)
            throw error
        }
    }

    private func load(pointerAt url: URL, now: Date) throws -> VerifiedHotVocabularyPack {
        let pointer = try readPointer(at: url)
        let verified = try verifyVersion(at: versionDirectory(for: pointer), now: now)
        guard verified.manifest.packVersion == pointer.packVersion else {
            throw HotVocabularyStoreError.invalidPointer
        }
        return verified
    }

    private func verifyVersion(at directory: URL, now: Date) throws -> VerifiedHotVocabularyPack {
        let manifestData = try Data(contentsOf: directory.appendingPathComponent("manifest.json"))
        let packData = try Data(contentsOf: directory.appendingPathComponent("pack.json"))
        return try verifier.verify(manifestData: manifestData, packData: packData, now: now)
    }

    private func versionDirectory(for pointer: Pointer) -> URL {
        versionsDirectory.appendingPathComponent(pointer.directoryName, isDirectory: true)
    }

    private func readPointer(at url: URL) throws -> Pointer {
        let pointer = try HotVocabularyCoding.decoder.decode(Pointer.self, from: Data(contentsOf: url))
        guard ![".", ".."].contains(pointer.directoryName),
              pointer.directoryName.count <= 128,
              pointer.directoryName.range(of: #"^[A-Za-z0-9._-]+$"#, options: .regularExpression) != nil,
              ![".", ".."].contains(pointer.packVersion),
              pointer.packVersion.count <= 64,
              pointer.packVersion.range(of: #"^[A-Za-z0-9._-]+$"#, options: .regularExpression) != nil
        else {
            throw HotVocabularyStoreError.invalidPointer
        }
        return pointer
    }

    private func writePointer(_ pointer: Pointer, to url: URL) throws {
        let data = try HotVocabularyCoding.encoder.encode(pointer)
        try data.write(to: url, options: .atomic)
    }
}
