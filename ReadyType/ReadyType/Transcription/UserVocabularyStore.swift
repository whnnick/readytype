import Foundation

extension Notification.Name {
    static let readyTypeUserVocabularyDidChange = Notification.Name("readyTypeUserVocabularyDidChange")
}

struct UserVocabularyEntry: Codable, Equatable, Identifiable {
    var id: UUID
    var value: String
    var kind: UserVocabularyKind
    var aliases: [String]
    var scopes: [UserVocabularyScope]
    var source: UserVocabularySource
    var confidence: Double
    var confirmedCount: Int
    var ignoredAliases: [String]
    var createdAt: Date
    var updatedAt: Date
    var lastUsedAt: Date?

    init(
        id: UUID = UUID(),
        value: String,
        kind: UserVocabularyKind = .general,
        aliases: [String] = [],
        scopes: [UserVocabularyScope] = [.all],
        source: UserVocabularySource = .manual,
        confidence: Double = 1.0,
        confirmedCount: Int = 1,
        ignoredAliases: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lastUsedAt: Date? = nil
    ) {
        self.id = id
        self.value = value
        self.kind = kind
        self.aliases = aliases
        self.scopes = scopes
        self.source = source
        self.confidence = confidence
        self.confirmedCount = confirmedCount
        self.ignoredAliases = ignoredAliases
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastUsedAt = lastUsedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case value
        case kind
        case aliases
        case scopes
        case source
        case confidence
        case confirmedCount
        case ignoredAliases
        case createdAt
        case updatedAt
        case lastUsedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        value = try container.decode(String.self, forKey: .value)
        kind = try container.decode(UserVocabularyKind.self, forKey: .kind)
        aliases = try container.decodeIfPresent([String].self, forKey: .aliases) ?? []
        scopes = try container.decodeIfPresent([UserVocabularyScope].self, forKey: .scopes) ?? [.all]
        source = try container.decodeIfPresent(UserVocabularySource.self, forKey: .source) ?? .manual
        confidence = try container.decodeIfPresent(Double.self, forKey: .confidence) ?? 1.0
        confirmedCount = try container.decodeIfPresent(Int.self, forKey: .confirmedCount) ?? 1
        ignoredAliases = try container.decodeIfPresent([String].self, forKey: .ignoredAliases) ?? []
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        lastUsedAt = try container.decodeIfPresent(Date.self, forKey: .lastUsedAt)
    }
}

enum UserVocabularyKind: String, Codable, CaseIterable, Identifiable {
    case general
    case person
    case product
    case project
    case technical
    case company
    case phrase

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .general:
            return "其他"
        case .person:
            return "人名"
        case .product:
            return "产品"
        case .project:
            return "项目"
        case .technical:
            return "技术词"
        case .company:
            return "公司/组织"
        case .phrase:
            return "常用短语"
        }
    }

    var smartTermWeight: Double {
        switch self {
        case .person:
            return 130
        case .product, .project, .company:
            return 125
        case .technical:
            return 120
        case .phrase:
            return 110
        case .general:
            return 100
        }
    }
}

enum UserVocabularyScope: String, Codable, CaseIterable, Identifiable {
    case all
    case chat
    case email
    case document
    case technical
    case aiTool

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: "所有场景"
        case .chat: "聊天"
        case .email: "邮件"
        case .document: "文档"
        case .technical: "技术内容"
        case .aiTool: "AI 工具"
        }
    }
}

enum UserVocabularySource: String, Codable {
    case manual
    case imported
    case confirmedSuggestion
}

final class UserVocabularyStore {
    static let changedFileURLUserInfoKey = "fileURL"

    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    var storageURL: URL { fileURL }

    init(fileURL: URL = UserVocabularyStore.defaultFileURL()) {
        self.fileURL = fileURL
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    func load() throws -> [UserVocabularyEntry] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: fileURL)
        let decoded = try decoder.decode([UserVocabularyEntry].self, from: data)
        let normalized = Self.normalizedEntries(decoded)

        if normalized != decoded {
            try persist(normalized, notifyChange: false)
        }

        return normalized
    }

    func save(_ entries: [UserVocabularyEntry]) throws {
        let normalized = Self.normalizedEntries(entries)
        try persist(normalized, notifyChange: true)
    }

    private func persist(_ entries: [UserVocabularyEntry], notifyChange: Bool) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try encoder.encode(entries)
        try data.write(to: fileURL, options: [.atomic])
        guard notifyChange else {
            return
        }
        NotificationCenter.default.post(
            name: .readyTypeUserVocabularyDidChange,
            object: self,
            userInfo: [Self.changedFileURLUserInfoKey: fileURL]
        )
    }

    @discardableResult
    func add(
        value: String,
        kind: UserVocabularyKind = .general,
        aliases: [String] = []
    ) throws -> UserVocabularyEntry? {
        let values = Self.parsedValues(value)
        guard values.count == 1, let cleanValue = values.first else {
            return nil
        }

        var entries = try load()
        let key = cleanValue.normalizedSmartTermKey
        guard !entries.contains(where: { $0.value.normalizedSmartTermKey == key }) else {
            return nil
        }

        let now = Date()
        let entry = UserVocabularyEntry(
            value: cleanValue,
            kind: kind,
            aliases: Self.cleanedAliases(aliases, excluding: cleanValue),
            scopes: [.all],
            source: .manual,
            confidence: 1.0,
            confirmedCount: 1,
            createdAt: now,
            updatedAt: now
        )
        entries.append(entry)
        try save(entries)
        return entry
    }

    @discardableResult
    func importLines(_ text: String, kind: UserVocabularyKind = .general) throws -> [UserVocabularyEntry] {
        var imported: [UserVocabularyEntry] = []

        for value in Self.parsedValues(text) {
            if let entry = try add(value: value, kind: kind) {
                imported.append(entry)
            }
        }

        return imported
    }

    @discardableResult
    func confirmSuggestion(
        value: String,
        alias: String,
        kind: UserVocabularyKind,
        scopes: [UserVocabularyScope],
        confidence: Double
    ) throws -> UserVocabularyEntry? {
        guard let cleanValue = Self.cleanedValue(value) else {
            return nil
        }

        let cleanAliases = Self.cleanedAliases([alias], excluding: cleanValue)
        let now = Date()
        var entries = try load()
        let key = cleanValue.normalizedSmartTermKey

        if let index = entries.firstIndex(where: { $0.value.normalizedSmartTermKey == key }) {
            var entry = entries[index]
            entry.aliases = Self.mergingCleanedAliases(entry.aliases + cleanAliases, excluding: cleanValue)
            entry.ignoredAliases = Self.cleanedAliases(
                entry.ignoredAliases.filter { ignoredAlias in
                    !cleanAliases.contains { $0.caseInsensitiveCompare(ignoredAlias) == .orderedSame }
                },
                excluding: cleanValue
            )
            entry.scopes = Self.mergingScopes(entry.scopes + scopes)
            entry.confirmedCount += 1
            entry.confidence = max(entry.confidence, min(max(confidence, 0), 1))
            entry.updatedAt = now
            entry.lastUsedAt = now
            entries[index] = entry
            try save(entries)
            return entry
        }

        let entry = UserVocabularyEntry(
            value: cleanValue,
            kind: kind,
            aliases: cleanAliases,
            scopes: Self.mergingScopes(scopes),
            source: .confirmedSuggestion,
            confidence: min(max(confidence, 0), 1),
            confirmedCount: 1,
            ignoredAliases: [],
            createdAt: now,
            updatedAt: now,
            lastUsedAt: now
        )
        entries.append(entry)
        try save(entries)
        return entry
    }

    @discardableResult
    func ignoreSuggestion(value: String, alias: String) throws -> UserVocabularyEntry? {
        guard let cleanValue = Self.cleanedValue(value),
              let cleanAlias = Self.cleanedValue(alias),
              cleanAlias.normalizedSmartTermKey != cleanValue.normalizedSmartTermKey else {
            return nil
        }

        var entries = try load()
        let key = cleanValue.normalizedSmartTermKey
        guard let index = entries.firstIndex(where: { $0.value.normalizedSmartTermKey == key }) else {
            return nil
        }

        var entry = entries[index]
        entry.ignoredAliases = Self.mergingCleanedAliases(entry.ignoredAliases + [cleanAlias], excluding: cleanValue)
        entry.updatedAt = Date()
        entries[index] = entry
        try save(entries)
        return entry
    }

    func delete(id: UUID) throws {
        let entries = try load().filter { $0.id != id }
        try save(entries)
    }

    @discardableResult
    func splitWhitespaceSeparatedEntry(id: UUID) throws -> [UserVocabularyEntry] {
        var entries = try load()
        guard let index = entries.firstIndex(where: { $0.id == id }) else {
            return []
        }

        let original = entries[index]
        let values = original.value
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
        guard values.count > 1 else {
            return []
        }

        entries.remove(at: index)
        var existingKeys = Set(entries.map { $0.value.normalizedSmartTermKey })
        let now = Date()
        var replacements: [UserVocabularyEntry] = []

        for value in values where existingKeys.insert(value.normalizedSmartTermKey).inserted {
            replacements.append(
                UserVocabularyEntry(
                    value: value,
                    kind: original.kind,
                    scopes: original.scopes,
                    source: .manual,
                    confidence: 1,
                    confirmedCount: 1,
                    createdAt: now,
                    updatedAt: now
                )
            )
        }

        entries.append(contentsOf: replacements)
        try save(entries)
        return replacements
    }

    static func defaultFileURL() -> URL {
        let supportDirectory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser

        return supportDirectory
            .appendingPathComponent("ReadyType", isDirectory: true)
            .appendingPathComponent("UserVocabulary.json")
    }

    private static func normalizedEntries(_ entries: [UserVocabularyEntry]) -> [UserVocabularyEntry] {
        var seen: Set<String> = []
        var normalized: [UserVocabularyEntry] = []

        for originalEntry in entries {
            let values = parsedValues(originalEntry.value)

            for (index, cleanValue) in values.enumerated() {
                var entry = originalEntry
                if values.count > 1 {
                    entry.id = index == 0 ? originalEntry.id : UUID()
                    entry.aliases = []
                    entry.ignoredAliases = []
                }

                guard !isInternalDiagnosticEntry(entry, cleanValue: cleanValue) else {
                    continue
                }

                let key = cleanValue.normalizedSmartTermKey
                guard !seen.contains(key) else {
                    continue
                }

                seen.insert(key)
                entry.value = cleanValue
                entry.aliases = cleanedAliases(entry.aliases, excluding: cleanValue)
                entry.scopes = mergingScopes(entry.scopes)
                entry.confidence = min(max(entry.confidence, 0), 1)
                entry.confirmedCount = max(entry.confirmedCount, 1)
                entry.ignoredAliases = cleanedAliases(entry.ignoredAliases, excluding: cleanValue)
                normalized.append(entry)
            }
        }

        return normalized
    }

    private static func isInternalDiagnosticEntry(_ entry: UserVocabularyEntry, cleanValue: String) -> Bool {
        cleanValue.hasPrefix("ReadyTypeUITestTerm") &&
            entry.aliases.contains { $0.caseInsensitiveCompare("ReadyType UI Gate") == .orderedSame }
    }

    private static func cleanedValue(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func parsedValues(_ text: String) -> [String] {
        let separators = CharacterSet.newlines.union(CharacterSet(charactersIn: ",，、;；"))
        var seen: Set<String> = []

        return text.components(separatedBy: separators).compactMap { component in
            guard let value = cleanedValue(component) else {
                return nil
            }

            let key = value.normalizedSmartTermKey
            guard seen.insert(key).inserted else {
                return nil
            }
            return value
        }
    }

    private static func cleanedAliases(_ aliases: [String], excluding value: String) -> [String] {
        var seen: Set<String> = [value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()]
        var cleaned: [String] = []

        for alias in aliases {
            guard let cleanAlias = cleanedValue(alias) else {
                continue
            }

            let key = cleanAlias.lowercased()
            guard !key.isEmpty, !seen.contains(key) else {
                continue
            }

            seen.insert(key)
            cleaned.append(cleanAlias)
        }

        return cleaned
    }

    private static func mergingCleanedAliases(_ aliases: [String], excluding value: String) -> [String] {
        cleanedAliases(aliases, excluding: value)
    }

    private static func mergingScopes(_ scopes: [UserVocabularyScope]) -> [UserVocabularyScope] {
        var seen: Set<UserVocabularyScope> = []
        var merged: [UserVocabularyScope] = []

        for scope in scopes.isEmpty ? [.all] : scopes {
            guard !seen.contains(scope) else {
                continue
            }
            seen.insert(scope)
            merged.append(scope)
        }

        return merged
    }
}

extension UserVocabularyEntry {
    var smartTerm: SmartTerm {
        let sourceBonus: Double = switch source {
        case .manual:
            18
        case .imported:
            10
        case .confirmedSuggestion:
            8
        }
        let confidenceBonus = min(max(confidence, 0), 1) * 12
        let confirmedBonus = min(Double(max(confirmedCount, 1) - 1) * 4, 20)

        return SmartTerm(
            value: value,
            source: .userDefined,
            weight: kind.smartTermWeight + sourceBonus + confidenceBonus + confirmedBonus,
            aliases: aliases,
            scopes: scopes,
            aliasConfidence: source == .confirmedSuggestion ? max(0.82, min(confidence, 0.95)) : 0.82
        )
    }
}
