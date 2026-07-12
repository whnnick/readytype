import Charts
import SwiftUI

struct DashboardView: View {
    @State private var snapshot = UsageStatisticsSnapshot()
    private let store = UsageStatisticsStore()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("使用概览")
                        .font(.largeTitle.bold())
                    Text("看看 ReadyType 帮你完成了多少输入。统计只保存在这台 Mac，不保存转写正文。")
                        .foregroundStyle(ReadyTypeTheme.muted)
                }

                metrics
                trend
                summary
            }
            .padding(26)
        }
        .onAppear(perform: reload)
        .onReceive(NotificationCenter.default.publisher(for: UsageStatisticsStore.didChangeNotification)) { _ in
            reload()
        }
    }

    private var metrics: some View {
        ReadyTypePanel("累计使用") {
            HStack(spacing: 0) {
                metric(title: "语音输入", value: formatDuration(snapshot.totalRecordingSeconds))
                Divider().frame(height: 48)
                metric(title: "完成输入", value: "\(snapshot.totalInputs) 次")
                Divider().frame(height: 48)
                metric(title: "输出文字", value: formatCount(snapshot.totalOutputCharacters))
                Divider().frame(height: 48)
                metric(title: "预计节省", value: formatDuration(snapshot.estimatedSecondsSaved))
            }
        }
    }

    private var trend: some View {
        ReadyTypePanel("最近 14 天", subtitle: "每天完成的语音输入次数") {
            if recentDays.allSatisfy({ $0.completedInputs == 0 }) {
                VStack(spacing: 10) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.system(size: 28))
                        .foregroundStyle(ReadyTypeTheme.accent)
                    Text("完成第一次语音输入后，这里会显示你的使用趋势。")
                        .foregroundStyle(ReadyTypeTheme.muted)
                }
                .frame(maxWidth: .infinity, minHeight: 190)
            } else {
                Chart(recentDays) { day in
                    AreaMark(
                        x: .value("日期", day.date),
                        y: .value("次数", day.completedInputs)
                    )
                    .foregroundStyle(ReadyTypeTheme.accent.opacity(0.12))

                    LineMark(
                        x: .value("日期", day.date),
                        y: .value("次数", day.completedInputs)
                    )
                    .foregroundStyle(ReadyTypeTheme.accent)
                    .interpolationMethod(.catmullRom)
                }
                .chartYAxis { AxisMarks(position: .leading) }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 2)) { value in
                        AxisGridLine().foregroundStyle(ReadyTypeTheme.strokeSoft)
                        AxisValueLabel(format: .dateTime.month().day())
                    }
                }
                .frame(height: 220)
            }
        }
    }

    private var summary: some View {
        ReadyTypePanel("使用节奏", subtitle: "从 1.2.0 (72) 开始记录，不包含此前使用数据。") {
            HStack {
                Label("活跃 \(activeDays) 天", systemImage: "calendar")
                Spacer()
                Label("连续 \(currentStreak) 天", systemImage: "flame")
            }
            .font(.callout.weight(.medium))

            Text("预计节省时间按每分钟 40 个中文字符的保守键盘输入速度估算，仅用于了解趋势。")
                .font(.footnote)
                .foregroundStyle(ReadyTypeTheme.muted)
        }
    }

    private func metric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption).foregroundStyle(ReadyTypeTheme.muted)
            Text(value).font(.title3.weight(.semibold)).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
    }

    private var recentDays: [DailyUsageStatistics] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<14).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return snapshot.days.first(where: { calendar.isDate($0.date, inSameDayAs: date) })
                ?? DailyUsageStatistics(date: date, completedInputs: 0, recordingSeconds: 0, outputCharacters: 0)
        }
    }

    private var activeDays: Int { snapshot.days.filter { $0.completedInputs > 0 }.count }

    private var currentStreak: Int {
        let calendar = Calendar.current
        var date = calendar.startOfDay(for: Date())
        var streak = 0
        while snapshot.days.contains(where: { $0.completedInputs > 0 && calendar.isDate($0.date, inSameDayAs: date) }) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: date) else { break }
            date = previous
        }
        return streak
    }

    private func reload() { snapshot = store.load() }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        if seconds < 60 { return "\(Int(seconds.rounded())) 秒" }
        if seconds < 3_600 { return "\(Int((seconds / 60).rounded())) 分钟" }
        return String(format: "%.1f 小时", seconds / 3_600)
    }

    private func formatCount(_ count: Int) -> String {
        count >= 10_000 ? String(format: "%.1f 万字", Double(count) / 10_000) : "\(count) 字"
    }
}
