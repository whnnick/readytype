import Foundation

@MainActor
final class IdlePrewarmController {
    private let warmupService: LocalSpeechModelWarming
    private let launchDelay: Duration
    private let isRecording: () async -> Bool
    private let sleeper: (Duration) async -> Void
    private let onStateChange: (LocalSpeechModelState) -> Void
    private var task: Task<Void, Never>?

    init(
        warmupService: LocalSpeechModelWarming,
        launchDelay: Duration = .seconds(8),
        isRecording: @escaping () async -> Bool = { false },
        sleeper: @escaping (Duration) async -> Void = { duration in
            try? await Task.sleep(for: duration)
        },
        onStateChange: @escaping (LocalSpeechModelState) -> Void = { _ in }
    ) {
        self.warmupService = warmupService
        self.launchDelay = launchDelay
        self.isRecording = isRecording
        self.sleeper = sleeper
        self.onStateChange = onStateChange
    }

    func start() {
        task?.cancel()
        task = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            await self.sleeper(self.launchDelay)

            guard !Task.isCancelled else {
                return
            }

            guard await !self.isRecording() else {
                return
            }

            await self.warmupService.prewarmIfAllowed(reason: "launch-idle")
            self.onStateChange(self.warmupService.state)
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        warmupService.cancelPrewarm()
    }

    func waitUntilIdle() async {
        await task?.value
    }
}
