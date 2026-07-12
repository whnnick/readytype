import XCTest
@testable import ReadyType

@MainActor
final class UsageStatisticsStoreTests: XCTestCase {
    func testRecordsOnlyAggregateUsageValues() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReadyTypeUsageTests-\(UUID().uuidString)")
        let fileURL = directory.appendingPathComponent("UsageStatistics.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = UsageStatisticsStore(fileURL: fileURL)

        store.recordCompletedInput(recordingDuration: 12.5, outputText: "開始動工吧 ReadyType")

        let snapshot = store.load()
        XCTAssertEqual(snapshot.totalInputs, 1)
        XCTAssertEqual(snapshot.totalRecordingSeconds, 12.5, accuracy: 0.001)
        XCTAssertEqual(snapshot.totalOutputCharacters, 14)
        let persistedText = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertFalse(persistedText.contains("開始動工吧"))
        XCTAssertFalse(persistedText.contains("ReadyType"))
    }

    func testMultipleInputsOnSameDayAreMerged() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReadyTypeUsageTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = UsageStatisticsStore(fileURL: directory.appendingPathComponent("UsageStatistics.json"))

        store.recordCompletedInput(recordingDuration: 2, outputText: "第一条")
        store.recordCompletedInput(recordingDuration: 3, outputText: "第二条")

        let snapshot = store.load()
        XCTAssertEqual(snapshot.days.count, 1)
        XCTAssertEqual(snapshot.totalInputs, 2)
        XCTAssertEqual(snapshot.totalRecordingSeconds, 5, accuracy: 0.001)
    }

    func testStreakKeepsYesterdayUntilTodayEnds() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let today = Date(timeIntervalSince1970: 1_725_926_400)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let dayBefore = calendar.date(byAdding: .day, value: -2, to: today)!
        let snapshot = UsageStatisticsSnapshot(days: [
            DailyUsageStatistics(date: dayBefore, completedInputs: 2, recordingSeconds: 4, outputCharacters: 10),
            DailyUsageStatistics(date: yesterday, completedInputs: 1, recordingSeconds: 2, outputCharacters: 5)
        ])

        XCTAssertEqual(snapshot.currentStreak(calendar: calendar, now: today), 2)
    }

    func testClearRemovesPersistedStatistics() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReadyTypeUsageTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = UsageStatisticsStore(fileURL: directory.appendingPathComponent("UsageStatistics.json"))
        store.recordCompletedInput(recordingDuration: 2, outputText: "测试")

        try store.clear()

        XCTAssertEqual(store.load(), UsageStatisticsSnapshot())
    }
}
