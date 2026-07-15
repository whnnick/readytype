import Foundation

@MainActor
final class VoiceInputController {
    private let appState: AppState
    private let permissionService: PermissionService
    private let recorder: AudioRecordingManaging
    private let transcriber: SpeechTranscribing
    private let transcriptHandler: TranscriptHandling
    private let analyticsTracker: AnalyticsTracking
    private let feedbackSoundPlayer: VoiceFeedbackSoundPlaying
    private let now: () -> Date

    init(
        appState: AppState,
        permissionService: PermissionService,
        recorder: AudioRecordingManaging,
        transcriber: SpeechTranscribing,
        transcriptHandler: TranscriptHandling,
        analyticsTracker: AnalyticsTracking = NoopAnalyticsTracker(),
        feedbackSoundPlayer: VoiceFeedbackSoundPlaying = NoopVoiceFeedbackSoundPlayer(),
        now: @escaping () -> Date = Date.init
    ) {
        self.appState = appState
        self.permissionService = permissionService
        self.recorder = recorder
        self.transcriber = transcriber
        self.transcriptHandler = transcriptHandler
        self.analyticsTracker = analyticsTracker
        self.feedbackSoundPlayer = feedbackSoundPlayer
        self.now = now
    }

    func beginRecording() async throws {
        let permissions = await permissionService.requestCorePermissions()
        appState.lastTranscript = nil
        appState.lastOutput = nil
        appState.lastProcessingSummary = nil
        appState.lastVoiceRunMetrics = nil
        appState.userVocabularySuggestions = []

        guard permissions.canRecord else {
            let error = ReadyTypeError.microphonePermissionMissing
            apply(error)
            trackFailure(error)
            throw error
        }

        guard permissions.canTranscribe else {
            let error = ReadyTypeError.speechRecognitionPermissionMissing
            apply(error)
            trackFailure(error)
            throw error
        }

        do {
            await feedbackSoundPlayer.playActivationCue()
            try recorder.startRecording()
            appState.lastVoiceRunMetrics = VoiceRunMetrics(recordingStartedAt: now())
            appState.runtimeState = .recording
            appState.lastMessage = "正在语音输入"
            appState.lastVoiceRunMetrics?.inputFeedbackShownAt = now()
            analyticsTracker.track(
                .voiceInputStarted(
                    recognitionSelection: appState.speechRecognitionMode.analyticsValue,
                    outputMethod: appState.selectedMode.analyticsValue
                )
            )
        } catch let error as ReadyTypeError {
            apply(error)
            trackFailure(error)
            throw error
        } catch {
            let readyTypeError = ReadyTypeError.recordingFailed(error.localizedDescription)
            apply(readyTypeError)
            trackFailure(readyTypeError)
            throw readyTypeError
        }
    }

    func finishRecording() async throws {
        do {
            let recording = try recorder.stopRecording()
            appState.lastVoiceRunMetrics?.recordingStoppedAt = now()
            appState.lastVoiceRunMetrics?.recordingDuration = recording.duration
            appState.runtimeState = .transcribing
            appState.lastMessage = "正在识别 \(Self.formatDuration(recording.duration)) 语音"

            let transcript = try await transcriber.transcribe(recording: recording)
            appState.lastVoiceRunMetrics?.transcriptReadyAt = now()
            appState.lastTranscript = transcript
            appState.lastMessage = "已识别：\(Self.preview(transcript))"
            try await transcriptHandler.handleTranscript(transcript)
        } catch let error as ReadyTypeError {
            apply(error)
            trackFailure(error)
            throw error
        } catch {
            let readyTypeError = ReadyTypeError.transcriptionFailed(error.localizedDescription)
            apply(readyTypeError)
            trackFailure(readyTypeError)
            throw readyTypeError
        }
    }

    func cancelRecording() {
        analyticsTracker.track(.voiceInputCancelled(stage: .recording))
        recorder.cancelRecording()
        appState.runtimeState = .idle
        appState.lastMessage = "已取消本次输入"
        appState.lastVoiceRunMetrics = nil
    }

    private func apply(_ error: ReadyTypeError) {
        appState.runtimeState = .error(error.userMessage)
        appState.lastMessage = error.userMessage
    }

    private func trackFailure(_ error: ReadyTypeError) {
        analyticsTracker.track(.voiceInputFailed(stage: error.analyticsStage, code: error.analyticsCode))
    }

    private static func formatDuration(_ duration: TimeInterval) -> String {
        String(format: "%.1fs", duration)
    }

    private static func preview(_ text: String) -> String {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedText.count > 40 else {
            return trimmedText
        }

        return "\(trimmedText.prefix(40))..."
    }
}
