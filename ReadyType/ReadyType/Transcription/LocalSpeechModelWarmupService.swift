import Foundation

@MainActor
protocol LocalSpeechModelWarming: AnyObject {
    var state: LocalSpeechModelState { get }
    func prewarmIfAllowed(reason: String) async
    func cancelPrewarm()
}

struct LocalSpeechModelWarmupPolicy: Sendable {
    let isHighAccuracyRecognitionEnabled: @Sendable () -> Bool
    let isIdlePrewarmEnabled: @Sendable () -> Bool
    let isRecording: @Sendable () -> Bool
    let isLowPowerModeEnabled: @Sendable () -> Bool
    let isSystemUnderPressure: @Sendable () -> Bool
    let isLaunchDelaySatisfied: @Sendable () -> Bool

    init(
        isHighAccuracyRecognitionEnabled: @escaping @Sendable () -> Bool,
        isIdlePrewarmEnabled: @escaping @Sendable () -> Bool,
        isRecording: @escaping @Sendable () -> Bool,
        isLowPowerModeEnabled: @escaping @Sendable () -> Bool,
        isSystemUnderPressure: @escaping @Sendable () -> Bool,
        isLaunchDelaySatisfied: @escaping @Sendable () -> Bool = { true }
    ) {
        self.isHighAccuracyRecognitionEnabled = isHighAccuracyRecognitionEnabled
        self.isIdlePrewarmEnabled = isIdlePrewarmEnabled
        self.isRecording = isRecording
        self.isLowPowerModeEnabled = isLowPowerModeEnabled
        self.isSystemUnderPressure = isSystemUnderPressure
        self.isLaunchDelaySatisfied = isLaunchDelaySatisfied
    }

    static let alwaysAllow = LocalSpeechModelWarmupPolicy(
        isHighAccuracyRecognitionEnabled: { true },
        isIdlePrewarmEnabled: { true },
        isRecording: { false },
        isLowPowerModeEnabled: { false },
        isSystemUnderPressure: { false },
        isLaunchDelaySatisfied: { true }
    )

    var allowsPrewarm: Bool {
        isHighAccuracyRecognitionEnabled()
            && isIdlePrewarmEnabled()
            && !isRecording()
            && !isLowPowerModeEnabled()
            && !isSystemUnderPressure()
            && isLaunchDelaySatisfied()
    }
}

@MainActor
final class LocalSpeechModelWarmupService: LocalSpeechModelWarming {
    private(set) var state: LocalSpeechModelState

    private let policy: LocalSpeechModelWarmupPolicy
    private let warmup: () async throws -> Void

    init(
        initialState: LocalSpeechModelState,
        policy: LocalSpeechModelWarmupPolicy,
        warmup: @escaping () async throws -> Void
    ) {
        self.state = initialState
        self.policy = policy
        self.warmup = warmup
    }

    func prewarmIfAllowed(reason: String) async {
        guard policy.allowsPrewarm else {
            return
        }

        guard state == .downloadedCold else {
            return
        }

        state = .warming

        do {
            try await warmup()
            state = .warm
        } catch {
            state = .failed(reason: "更准确的识别准备失败：\(errorMessage(from: error))")
        }
    }

    func cancelPrewarm() {
        if state == .warming {
            state = .downloadedCold
        }
    }

    private func errorMessage(from error: Error) -> String {
        if case let ReadyTypeError.transcriptionFailed(message) = error {
            return message
        }

        return error.localizedDescription
    }
}
