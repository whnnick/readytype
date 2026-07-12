import Foundation

struct DailyUsageStatistics: Codable, Equatable, Identifiable {
    var date: Date
    var completedInputs: Int
    var recordingSeconds: TimeInterval
    var outputCharacters: Int

    var id: Date { date }
}

struct UsageStatisticsSnapshot: Codable, Equatable {
    var days: [DailyUsageStatistics] = []

    var totalInputs: Int { days.reduce(0) { $0 + $1.completedInputs } }
    var totalRecordingSeconds: TimeInterval { days.reduce(0) { $0 + $1.recordingSeconds } }
    var totalOutputCharacters: Int { days.reduce(0) { $0 + $1.outputCharacters } }
    var estimatedSecondsSaved: TimeInterval {
        max(0, Double(totalOutputCharacters) / 40 * 60 - totalRecordingSeconds)
    }
}

@MainActor
protocol UsageStatisticsRecording: AnyObject {
    func recordCompletedInput(recordingDuration: TimeInterval, outputText: String)
}

@MainActor
final class UsageStatisticsStore: UsageStatisticsRecording {
    static let didChangeNotification = Notification.Name("ReadyTypeUsageStatisticsDidChange")

    private let fileURL: URL
    private let calendar: Calendar

    init(fileURL: URL = UsageStatisticsStore.defaultFileURL(), calendar: Calendar = .current) {
        self.fileURL = fileURL
        self.calendar = calendar
    }

    func load() -> UsageStatisticsSnapshot {
        guard let data = try? Data(contentsOf: fileURL),
              let snapshot = try? JSONDecoder().decode(UsageStatisticsSnapshot.self, from: data)
        else {
            return UsageStatisticsSnapshot()
        }
        return snapshot
    }

    func recordCompletedInput(recordingDuration: TimeInterval, outputText: String) {
        var snapshot = load()
        let today = calendar.startOfDay(for: Date())
        let characterCount = outputText.unicodeScalars.filter {
            !CharacterSet.whitespacesAndNewlines.contains($0)
        }.count

        if let index = snapshot.days.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: today) }) {
            snapshot.days[index].completedInputs += 1
            snapshot.days[index].recordingSeconds += max(0, recordingDuration)
            snapshot.days[index].outputCharacters += characterCount
        } else {
            snapshot.days.append(
                DailyUsageStatistics(
                    date: today,
                    completedInputs: 1,
                    recordingSeconds: max(0, recordingDuration),
                    outputCharacters: characterCount
                )
            )
        }

        snapshot.days = snapshot.days
            .filter { calendar.dateComponents([.day], from: $0.date, to: today).day ?? 0 <= 365 }
            .sorted { $0.date < $1.date }

        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: fileURL, options: .atomic)
            NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
        } catch {
            return
        }
    }

    static func defaultFileURL() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ReadyType", isDirectory: true)
            .appendingPathComponent("UsageStatistics.json")
    }
}
