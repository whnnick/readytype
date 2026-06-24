import Foundation

enum RecordingPolicy {
    static let defaultMaximumDurationSeconds = 60
    static let defaultMaximumDuration: Duration = .seconds(defaultMaximumDurationSeconds)
    static let autoFinishMessage = "本次语音输入达到 \(defaultMaximumDurationSeconds) 秒上限，正在识别..."
}
