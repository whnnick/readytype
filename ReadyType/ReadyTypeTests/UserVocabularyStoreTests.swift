import XCTest
@testable import ReadyType

final class UserVocabularyStoreTests: XCTestCase {
    func testAddTrimsDeduplicatesAndPersistsEntries() throws {
        let context = try makeContext()
        defer { context.cleanup() }

        let first = try context.store.add(value: " ReadyPlay ", kind: .product, aliases: ["ready play", ""])
        let duplicate = try context.store.add(value: "readyplay", kind: .technical, aliases: ["ready tape"])

        XCTAssertNotNil(first)
        XCTAssertNil(duplicate)

        let reloadedStore = UserVocabularyStore(fileURL: context.fileURL)
        let entries = try reloadedStore.load()

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.id, first?.id)
        XCTAssertEqual(entries.first?.value, "ReadyPlay")
        XCTAssertEqual(entries.first?.kind, .product)
        XCTAssertEqual(entries.first?.aliases, ["ready play"])
    }

    func testImportLinesAddsOneTermPerLineAndIgnoresBlankOrDuplicateLines() throws {
        let context = try makeContext()
        defer { context.cleanup() }

        let imported = try context.store.importLines(
            """
            张三

            ReadyType
            readytype
            """
            ,
            kind: .person
        )

        XCTAssertEqual(imported.map(\.value), ["张三", "ReadyType"])
        XCTAssertEqual(try context.store.load().map(\.value), ["张三", "ReadyType"])
    }

    func testImportSplitsSupportedSeparatorsAndPreservesSpacesInsideTerms() throws {
        let context = try makeContext()
        defer { context.cleanup() }

        let imported = try context.store.importLines(
            "ChatGPT, Codex，DeepSeek、GitHub Actions;ReadyType；chatgpt",
            kind: .technical
        )

        XCTAssertEqual(
            imported.map(\.value),
            ["ChatGPT", "Codex", "DeepSeek", "GitHub Actions", "ReadyType"]
        )
        XCTAssertEqual(try context.store.load().count, 5)
    }

    func testAddOneRejectsSeparatorCombinedValues() throws {
        let context = try makeContext()
        defer { context.cleanup() }

        XCTAssertNil(try context.store.add(value: "ChatGPT, Codex"))
        XCTAssertEqual(try context.store.load(), [])
    }

    func testLoadMigratesCombinedValuesAndDeduplicatesIndividualTerms() throws {
        let context = try makeContext()
        defer { context.cleanup() }
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        let firstID = UUID()

        let legacyEntries = [
            UserVocabularyEntry(id: firstID, value: "ChatGPT, Codex", kind: .technical, createdAt: now, updatedAt: now),
            UserVocabularyEntry(value: "chatgpt、Google", kind: .technical, createdAt: now, updatedAt: now)
        ]
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(legacyEntries).write(to: context.fileURL)

        let entries = try context.store.load()

        XCTAssertEqual(entries.map(\.value), ["ChatGPT", "Codex", "Google"])
        XCTAssertEqual(entries.first?.id, firstID)
        XCTAssertEqual(try UserVocabularyStore(fileURL: context.fileURL).load().map(\.value), ["ChatGPT", "Codex", "Google"])
    }

    func testProductizedKindsUseUserFacingCategories() throws {
        XCTAssertEqual(
            UserVocabularyKind.allCases.map(\.displayName),
            ["其他", "人名", "产品", "项目", "技术词", "公司/组织", "常用短语"]
        )
    }

    func testCompanyKindPersistsForOrganizations() throws {
        let context = try makeContext()
        defer { context.cleanup() }

        let entry = try XCTUnwrap(context.store.add(value: "DeepSeek", kind: .company))

        XCTAssertEqual(entry.kind, .company)
        XCTAssertEqual(try context.store.load().first?.kind, .company)
    }

    func testDeleteRemovesEntry() throws {
        let context = try makeContext()
        defer { context.cleanup() }

        let entry = try XCTUnwrap(context.store.add(value: "DeepSeek", kind: .product))

        try context.store.delete(id: entry.id)

        XCTAssertEqual(try context.store.load(), [])
    }

    func testLoadFiltersInternalDiagnosticVocabularyEntries() throws {
        let context = try makeContext()
        defer { context.cleanup() }
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        try context.store.save([
            UserVocabularyEntry(
                value: "ReadyTypeUITestTerm1781424784",
                kind: .product,
                aliases: ["ReadyType UI Gate"],
                createdAt: now,
                updatedAt: now
            ),
            UserVocabularyEntry(
                value: "ReadyType",
                kind: .technical,
                aliases: ["Reddit Tab"],
                createdAt: now,
                updatedAt: now
            )
        ])

        let entries = try context.store.load()

        XCTAssertEqual(entries.map(\.value), ["ReadyType"])
        XCTAssertEqual(entries.first?.aliases, ["Reddit Tab"])
    }

    func testLoadMigratesLegacyEntriesWithLearningDefaults() throws {
        let context = try makeContext()
        defer { context.cleanup() }
        let legacyJSON = """
        [
          {
            "aliases" : [
              "ready play"
            ],
            "createdAt" : "2026-06-18T10:00:00Z",
            "id" : "00000000-0000-0000-0000-000000000001",
            "kind" : "product",
            "updatedAt" : "2026-06-18T10:00:00Z",
            "value" : "ReadyPlay"
          }
        ]
        """
        try legacyJSON.data(using: .utf8)?.write(to: context.fileURL)

        let entries = try context.store.load()

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].value, "ReadyPlay")
        XCTAssertEqual(entries[0].scopes, [.all])
        XCTAssertEqual(entries[0].source, .manual)
        XCTAssertEqual(entries[0].confidence, 1.0)
        XCTAssertEqual(entries[0].confirmedCount, 1)
        XCTAssertEqual(entries[0].ignoredAliases, [])
        XCTAssertNil(entries[0].lastUsedAt)
    }

    func testConfirmSuggestionCreatesConfirmedEntryWithAliasAndScope() throws {
        let context = try makeContext()
        defer { context.cleanup() }

        let entry = try XCTUnwrap(context.store.confirmSuggestion(
            value: "ReadyType",
            alias: "Reddit Tab",
            kind: .product,
            scopes: [.technical],
            confidence: 0.88
        ))

        XCTAssertEqual(entry.value, "ReadyType")
        XCTAssertEqual(entry.aliases, ["Reddit Tab"])
        XCTAssertEqual(entry.scopes, [.technical])
        XCTAssertEqual(entry.source, .confirmedSuggestion)
        XCTAssertEqual(entry.confidence, 0.88)
        XCTAssertEqual(entry.confirmedCount, 1)
        XCTAssertNotNil(entry.lastUsedAt)
        let savedEntry = try XCTUnwrap(context.store.load().first)
        XCTAssertEqual(savedEntry.value, entry.value)
        XCTAssertEqual(savedEntry.aliases, entry.aliases)
        XCTAssertEqual(savedEntry.scopes, entry.scopes)
        XCTAssertEqual(savedEntry.source, entry.source)
    }

    func testConfirmSuggestionUpdatesExistingEntryWithoutDuplicatingAliases() throws {
        let context = try makeContext()
        defer { context.cleanup() }
        _ = try context.store.add(value: "ReadyType", kind: .product, aliases: ["Ready Tap"])

        let entry = try XCTUnwrap(context.store.confirmSuggestion(
            value: "ReadyType",
            alias: "Reddit Tab",
            kind: .technical,
            scopes: [.technical],
            confidence: 0.9
        ))

        XCTAssertEqual(entry.value, "ReadyType")
        XCTAssertEqual(entry.kind, .product)
        XCTAssertEqual(entry.aliases, ["Ready Tap", "Reddit Tab"])
        XCTAssertEqual(entry.scopes, [.all, .technical])
        XCTAssertEqual(entry.confirmedCount, 2)
        XCTAssertEqual(entry.confidence, 1.0)
        XCTAssertEqual(try context.store.load().count, 1)
    }

    func testIgnoreSuggestionAddsIgnoredAliasToExistingEntryOnly() throws {
        let context = try makeContext()
        defer { context.cleanup() }
        _ = try context.store.add(value: "ReadyType", kind: .product, aliases: ["Ready Tap"])

        let entry = try XCTUnwrap(context.store.ignoreSuggestion(value: "ReadyType", alias: "Reddit Tab"))

        XCTAssertEqual(entry.value, "ReadyType")
        XCTAssertEqual(entry.aliases, ["Ready Tap"])
        XCTAssertEqual(entry.ignoredAliases, ["Reddit Tab"])
        XCTAssertEqual(entry.confirmedCount, 1)
        XCTAssertEqual(try context.store.load().count, 1)
    }

    func testUserVocabularyMergesIntoSmartTermDictionaryWithUserPriority() {
        let entry = UserVocabularyEntry(
            value: "ReadyPlay",
            kind: .product,
            aliases: ["ready play"]
        )

        let dictionary = SmartTermDictionary(terms: [
            SmartTerm(value: "ReadyPlay", source: .builtIn, weight: 1)
        ]).mergingUserVocabulary([entry])

        XCTAssertEqual(dictionary.terms.count, 1)
        XCTAssertEqual(dictionary.terms.first?.source, .userDefined)
        XCTAssertEqual(dictionary.terms.first?.aliases, ["ready play"])
    }

    func testConfirmedSuggestionMapsToScopedSmartTermWithConfidenceAndUsageWeight() throws {
        let manualEntry = UserVocabularyEntry(
            value: "ReadyType",
            kind: .product,
            aliases: ["Ready Tap"],
            scopes: [.all],
            source: .manual,
            confidence: 1.0,
            confirmedCount: 1
        )
        let confirmedEntry = UserVocabularyEntry(
            value: "ReadyType",
            kind: .product,
            aliases: ["Reddit Tab"],
            scopes: [.technical],
            source: .confirmedSuggestion,
            confidence: 0.88,
            confirmedCount: 4
        )

        let manualTerm = manualEntry.smartTerm
        let confirmedTerm = confirmedEntry.smartTerm

        XCTAssertEqual(confirmedTerm.scopes, [.technical])
        XCTAssertEqual(confirmedTerm.aliasConfidence, 0.88)
        XCTAssertGreaterThan(confirmedTerm.weight, manualTerm.weight)
    }

    private func makeContext() throws -> TestContext {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReadyTypeUserVocabularyStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("user-vocabulary.json")
        return TestContext(
            directory: directory,
            fileURL: fileURL,
            store: UserVocabularyStore(fileURL: fileURL)
        )
    }

    private struct TestContext {
        var directory: URL
        var fileURL: URL
        var store: UserVocabularyStore

        func cleanup() {
            try? FileManager.default.removeItem(at: directory)
        }
    }
}
