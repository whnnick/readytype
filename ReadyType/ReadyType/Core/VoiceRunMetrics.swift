import Foundation

struct VoiceRunMetrics: Equatable {
    var recordingStartedAt: Date?
    var inputFeedbackShownAt: Date?
    var recordingStoppedAt: Date?
    var transcriptReadyAt: Date?
    var outputCompletedAt: Date?
    var recordingDuration: TimeInterval?

    var inputFeedbackLatencyMilliseconds: Int? {
        milliseconds(from: recordingStartedAt, to: inputFeedbackShownAt)
    }

    var firstPreviewLatencyMilliseconds: Int? {
        milliseconds(from: recordingStartedAt, to: transcriptReadyAt)
    }

    var stopToOutputLatencyMilliseconds: Int? {
        milliseconds(from: recordingStoppedAt, to: outputCompletedAt)
    }

    var totalCompletionLatencyMilliseconds: Int? {
        milliseconds(from: recordingStartedAt, to: outputCompletedAt)
    }

    var transcriptionLatencyMilliseconds: Int? {
        milliseconds(from: recordingStoppedAt, to: transcriptReadyAt)
    }

    var processingAndPasteLatencyMilliseconds: Int? {
        milliseconds(from: transcriptReadyAt, to: outputCompletedAt)
    }

    var summaryLine: String? {
        let parts: [String] = [
            formatted("反馈", inputFeedbackLatencyMilliseconds),
            formatted("识别", transcriptionLatencyMilliseconds),
            formatted("停止到输出", stopToOutputLatencyMilliseconds),
            formatted("总计", totalCompletionLatencyMilliseconds)
        ].compactMap { $0 }

        guard !parts.isEmpty else {
            return nil
        }

        return "耗时：\(parts.joined(separator: " / "))"
    }

    private func milliseconds(from start: Date?, to end: Date?) -> Int? {
        guard let start, let end else {
            return nil
        }

        return max(0, Int((end.timeIntervalSince(start) * 1_000).rounded()))
    }

    private func formatted(_ label: String, _ milliseconds: Int?) -> String? {
        guard let milliseconds else {
            return nil
        }

        return "\(label) \(milliseconds)ms"
    }
}
