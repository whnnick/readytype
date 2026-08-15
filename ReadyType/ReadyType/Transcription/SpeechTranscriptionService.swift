import Foundation
import Speech
@preconcurrency import WhisperKit

@MainActor
protocol SpeechRecognitionBackend: AnyObject {
    func transcribeAudio(at fileURL: URL) async throws -> String
}

@MainActor
protocol ContextualSpeechRecognitionBackend: SpeechRecognitionBackend {
    func transcribeAudio(at fileURL: URL, contextualTerms: [String]) async throws -> String
}

@MainActor
protocol SpeechRecognitionCandidateBackend: AnyObject {
    func recognizeAudio(at fileURL: URL, contextualTerms: [String]) async throws -> SpeechRecognitionCandidate
}

extension ContextualSpeechRecognitionBackend {
    func transcribeAudio(at fileURL: URL) async throws -> String {
        try await transcribeAudio(at: fileURL, contextualTerms: [])
    }
}

@MainActor
protocol RecordingSpeechRecognitionBackend: AnyObject {
    func transcribe(recording: AudioRecording) async throws -> String
}

@MainActor
protocol SpeechTranscribing: AnyObject {
    func transcribe(recording: AudioRecording) async throws -> String
}

final class SpeechTranscriptionService: SpeechTranscribing {
    private let backend: RecordingSpeechRecognitionBackend

    convenience init() {
        self.init(recordingBackend: RoutedSpeechRecognitionBackend())
    }

    convenience init(backend: SpeechRecognitionBackend) {
        self.init(recordingBackend: AudioFileRecognitionBackendAdapter(backend: backend))
    }

    init(recordingBackend: RecordingSpeechRecognitionBackend) {
        self.backend = recordingBackend
    }

    func transcribe(recording: AudioRecording) async throws -> String {
        do {
            let transcript = try await backend.transcribe(recording: recording)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !transcript.isEmpty else {
                throw ReadyTypeError.transcriptionEmpty
            }

            guard !SpeechTranscriptValidator.isLikelyHallucination(transcript) else {
                throw ReadyTypeError.transcriptionEmpty
            }

            return transcript
        } catch let error as ReadyTypeError {
            throw error
        } catch {
            throw ReadyTypeError.transcriptionFailed(Self.stableErrorDescription(for: error))
        }
    }

    private static func stableErrorDescription(for error: Error) -> String {
        let nsError = error as NSError
        return "\(nsError.domain) error \(nsError.code)"
    }
}

private final class AudioFileRecognitionBackendAdapter: RecordingSpeechRecognitionBackend {
    private let backend: SpeechRecognitionBackend

    init(backend: SpeechRecognitionBackend) {
        self.backend = backend
    }

    func transcribe(recording: AudioRecording) async throws -> String {
        try await backend.transcribeAudio(at: recording.fileURL)
    }
}

final class RoutedSpeechRecognitionBackend: RecordingSpeechRecognitionBackend {
    typealias ContextProvider = @MainActor (AudioRecording) -> SpeechRecognitionRouteContext
    typealias DecisionObserver = @MainActor (SpeechRecognitionRouteDecision) -> Void

    private let router: SpeechRecognitionRouter
    private let fastSystemBackend: SpeechRecognitionBackend
    private let highAccuracyBackend: SpeechRecognitionBackend
    private let contextProvider: ContextProvider
    private let onDecision: DecisionObserver?
    private let automaticHighAccuracyTimeout: Duration
    private let candidateSelector = SpeechRecognitionCandidateSelector()

    init(
        router: SpeechRecognitionRouter = SpeechRecognitionRouter(),
        fastSystemBackend: SpeechRecognitionBackend = FastSystemSpeechBackend(),
        highAccuracyBackend: SpeechRecognitionBackend = LocalHighAccuracySpeechBackend(),
        contextProvider: @escaping ContextProvider = RoutedSpeechRecognitionBackend.defaultContext,
        onDecision: DecisionObserver? = nil,
        automaticHighAccuracyTimeout: Duration = .seconds(3)
    ) {
        self.router = router
        self.fastSystemBackend = fastSystemBackend
        self.highAccuracyBackend = highAccuracyBackend
        self.contextProvider = contextProvider
        self.onDecision = onDecision
        self.automaticHighAccuracyTimeout = automaticHighAccuracyTimeout
    }

    func transcribe(recording: AudioRecording) async throws -> String {
        let context = contextProvider(recording)
        let decision = router.route(context: context)
        onDecision?(decision)

        switch decision.backend {
        case .fastSystem:
            return try await transcribeWithFastSystem(recording: recording, contextualTerms: context.contextualTerms)
        case .highAccuracyLocal:
            if context.mode == .automatic {
                return try await transcribeAutomaticHighAccuracy(
                    recording: recording,
                    contextualTerms: context.contextualTerms
                )
            }

            do {
                return try await recognize(
                    with: highAccuracyBackend,
                    fileURL: recording.fileURL,
                    contextualTerms: context.contextualTerms
                ).transcript
            } catch {
                onDecision?(
                    SpeechRecognitionRouteDecision(
                        backend: .fastSystem,
                        fallbackReason: "高精度识别失败，已使用极速识别。"
                    )
                )
                return try await transcribeWithFastSystem(recording: recording, contextualTerms: context.contextualTerms)
            }
        }
    }

    private func transcribeAutomaticHighAccuracy(
        recording: AudioRecording,
        contextualTerms: [String]
    ) async throws -> String {
        let (stream, continuation) = AsyncStream<AutomaticRecognitionEvent>.makeStream()
        defer { continuation.finish() }

        let highAccuracyTask = Task { @MainActor in
            do {
                let candidate = try await recognize(
                    with: highAccuracyBackend,
                    fileURL: recording.fileURL,
                    contextualTerms: contextualTerms
                )
                guard !Task.isCancelled else { return }
                continuation.yield(.highAccuracySucceeded(candidate))
            } catch is CancellationError {
                return
            } catch {
                continuation.yield(.highAccuracyFailed(error))
            }
        }

        let fastSystemTask = Task { @MainActor in
            do {
                let candidate = try await recognizeWithFastSystem(
                    recording: recording,
                    contextualTerms: contextualTerms
                )
                guard !Task.isCancelled else { return }
                continuation.yield(.fastSystemSucceeded(candidate))
            } catch is CancellationError {
                return
            } catch {
                continuation.yield(.fastSystemFailed(error))
            }
        }

        let timeoutTask = Task {
            do {
                try await Task.sleep(for: automaticHighAccuracyTimeout)
                continuation.yield(.highAccuracyTimedOut)
            } catch {
                return
            }
        }

        continuation.onTermination = { _ in
            highAccuracyTask.cancel()
            fastSystemTask.cancel()
            timeoutTask.cancel()
        }

        var fastSystemResult: Result<SpeechRecognitionCandidate, Error>?
        var highAccuracyResult: Result<SpeechRecognitionCandidate, Error>?
        var didReachTimeout = false

        for await event in stream {
            switch event {
            case let .highAccuracySucceeded(candidate):
                if !didReachTimeout {
                    highAccuracyResult = .success(candidate)
                }
            case let .highAccuracyFailed(error):
                highAccuracyResult = .failure(error)
            case .highAccuracyTimedOut:
                didReachTimeout = true
                highAccuracyTask.cancel()
            case let .fastSystemSucceeded(candidate):
                fastSystemResult = .success(candidate)
            case let .fastSystemFailed(error):
                fastSystemResult = .failure(error)
            }

            let fastCandidate = fastSystemResult?.successValue
            let highCandidate = highAccuracyResult?.successValue

            if let selection = candidateSelector.select(
                fastSystem: fastCandidate,
                highAccuracy: highCandidate,
                deadlineReached: didReachTimeout
                    || highAccuracyResult?.isFailure == true
                    || fastSystemResult?.isFailure == true
            ) {
                if selection.backend == .fastSystem {
                    let reason: String
                    if highAccuracyResult?.isFailure == true {
                        reason = "高精度识别失败，已使用极速识别。"
                    } else if didReachTimeout, highCandidate == nil {
                        reason = "高精度识别等待过久，已使用极速识别。"
                    } else {
                        reason = "已采用更稳定的识别结果。"
                    }
                    onDecision?(SpeechRecognitionRouteDecision(backend: .fastSystem, fallbackReason: reason))
                }
                return selection.candidate.transcript
            }

            if let fastSystemResult, let highAccuracyResult,
               fastSystemResult.isFailure, highAccuracyResult.isFailure {
                return try highAccuracyResult.get().transcript
            }

            if fastSystemResult != nil, highAccuracyResult != nil {
                throw ReadyTypeError.transcriptionEmpty
            }

            if didReachTimeout, let fastSystemResult {
                switch fastSystemResult {
                case let .success(candidate):
                    guard !SpeechTranscriptValidator.isLikelyHallucination(candidate.transcript) else {
                        throw ReadyTypeError.transcriptionEmpty
                    }
                    return candidate.transcript
                case let .failure(error):
                    throw error
                }
            }
        }

        throw ReadyTypeError.transcriptionFailed("语音识别未返回结果")
    }

    private func transcribeWithFastSystem(recording: AudioRecording, contextualTerms: [String]) async throws -> String {
        try await recognizeWithFastSystem(recording: recording, contextualTerms: contextualTerms).transcript
    }

    private func recognizeWithFastSystem(
        recording: AudioRecording,
        contextualTerms: [String]
    ) async throws -> SpeechRecognitionCandidate {
        try await recognize(
            with: fastSystemBackend,
            fileURL: recording.fileURL,
            contextualTerms: contextualTerms
        )
    }

    private func recognize(
        with backend: SpeechRecognitionBackend,
        fileURL: URL,
        contextualTerms: [String]
    ) async throws -> SpeechRecognitionCandidate {
        let cappedTerms = Array(contextualTerms.prefix(100))

        if let candidateBackend = backend as? SpeechRecognitionCandidateBackend {
            return try await candidateBackend.recognizeAudio(at: fileURL, contextualTerms: cappedTerms)
        }

        if let contextualBackend = backend as? ContextualSpeechRecognitionBackend {
            let transcript = try await contextualBackend.transcribeAudio(at: fileURL, contextualTerms: cappedTerms)
            return SpeechRecognitionCandidate(transcript: transcript)
        }

        let transcript = try await backend.transcribeAudio(at: fileURL)
        return SpeechRecognitionCandidate(transcript: transcript)
    }

    static func defaultContext(for recording: AudioRecording) -> SpeechRecognitionRouteContext {
        SpeechRecognitionRouteContext(
            mode: .automatic,
            scenario: .generic,
            frontmostAppBundleIdentifier: nil,
            recordingDuration: recording.duration,
            hasLowConfidenceSignal: false,
            hasChineseMisclassifiedAsEnglishSignal: false,
            isLowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled,
            localModelState: LocalSpeechModelManager().state(),
            contextualTerms: []
        )
    }
}

private extension Result {
    var successValue: Success? {
        guard case let .success(value) = self else {
            return nil
        }
        return value
    }

    var isFailure: Bool {
        if case .failure = self {
            return true
        }
        return false
    }
}

private enum AutomaticRecognitionEvent {
    case highAccuracySucceeded(SpeechRecognitionCandidate)
    case highAccuracyFailed(Error)
    case highAccuracyTimedOut
    case fastSystemSucceeded(SpeechRecognitionCandidate)
    case fastSystemFailed(Error)
}

final class FastSystemSpeechBackend: ContextualSpeechRecognitionBackend, SpeechRecognitionCandidateBackend {
    private let systemSpeechBackend: SpeechRecognitionBackend

    init(systemSpeechBackend: SpeechRecognitionBackend = SFSpeechRecognitionBackend()) {
        self.systemSpeechBackend = systemSpeechBackend
    }

    func transcribeAudio(at fileURL: URL, contextualTerms: [String]) async throws -> String {
        try await recognizeAudio(at: fileURL, contextualTerms: contextualTerms).transcript
    }

    func recognizeAudio(at fileURL: URL, contextualTerms: [String]) async throws -> SpeechRecognitionCandidate {
        if let candidateBackend = systemSpeechBackend as? SpeechRecognitionCandidateBackend {
            return try await candidateBackend.recognizeAudio(at: fileURL, contextualTerms: contextualTerms)
        }

        if let contextualBackend = systemSpeechBackend as? ContextualSpeechRecognitionBackend {
            let transcript = try await contextualBackend.transcribeAudio(at: fileURL, contextualTerms: contextualTerms)
            return SpeechRecognitionCandidate(transcript: transcript)
        }

        let transcript = try await systemSpeechBackend.transcribeAudio(at: fileURL)
        return SpeechRecognitionCandidate(transcript: transcript)
    }
}

enum LocalHighAccuracySpeechEngineKind: Equatable {
    case whisperKit
}

@MainActor
protocol LocalHighAccuracySpeechEngine: AnyObject {
    func transcribeAudio(at fileURL: URL) async throws -> String
    func transcribeAudio(at fileURL: URL, contextualTerms: [String]) async throws -> String
    func prewarm() async throws
}

@MainActor
protocol LocalHighAccuracySpeechCandidateEngine: AnyObject {
    func recognizeAudio(at fileURL: URL, contextualTerms: [String]) async throws -> SpeechRecognitionCandidate
}

extension LocalHighAccuracySpeechEngine {
    func transcribeAudio(at fileURL: URL, contextualTerms: [String]) async throws -> String {
        try await transcribeAudio(at: fileURL)
    }
}

final class LocalHighAccuracySpeechBackend: ContextualSpeechRecognitionBackend, SpeechRecognitionCandidateBackend {
    let engineKind: LocalHighAccuracySpeechEngineKind

    private let engine: LocalHighAccuracySpeechEngine

    init(
        engine: LocalHighAccuracySpeechEngine = CoreMLHighAccuracySpeechEngine(),
        engineKind: LocalHighAccuracySpeechEngineKind = .whisperKit
    ) {
        self.engine = engine
        self.engineKind = engineKind
    }

    func transcribeAudio(at fileURL: URL) async throws -> String {
        try await engine.transcribeAudio(at: fileURL)
    }

    func transcribeAudio(at fileURL: URL, contextualTerms: [String]) async throws -> String {
        try await engine.transcribeAudio(at: fileURL, contextualTerms: contextualTerms)
    }

    func recognizeAudio(at fileURL: URL, contextualTerms: [String]) async throws -> SpeechRecognitionCandidate {
        if let candidateEngine = engine as? LocalHighAccuracySpeechCandidateEngine {
            return try await candidateEngine.recognizeAudio(at: fileURL, contextualTerms: contextualTerms)
        }

        let transcript = try await engine.transcribeAudio(at: fileURL, contextualTerms: contextualTerms)
        return SpeechRecognitionCandidate(transcript: transcript)
    }
}

final class CoreMLHighAccuracySpeechEngine: LocalHighAccuracySpeechEngine, LocalHighAccuracySpeechCandidateEngine {
    private let modelManager: LocalSpeechModelManager
    private let modelName: String
    private var pipeline: WhisperKit?

    init(
        modelManager: LocalSpeechModelManager = LocalSpeechModelManager(),
        modelName: String = LocalSpeechModelManager.defaultWhisperKitModelName
    ) {
        self.modelManager = modelManager
        self.modelName = modelName
    }

    func transcribeAudio(at fileURL: URL) async throws -> String {
        try await transcribeAudio(at: fileURL, contextualTerms: [])
    }

    func transcribeAudio(at fileURL: URL, contextualTerms: [String]) async throws -> String {
        try await recognizeAudio(at: fileURL, contextualTerms: contextualTerms).transcript
    }

    func recognizeAudio(at fileURL: URL, contextualTerms: [String]) async throws -> SpeechRecognitionCandidate {
        let pipe = try await pipeline(load: true, prewarm: false)
        var decodeOptions = DecodingOptions(language: "zh", chunkingStrategy: .vad)
        if let tokenizer = pipe.tokenizer,
           let prompt = Self.contextPrompt(from: contextualTerms) {
            decodeOptions.promptTokens = tokenizer
                .encode(text: " " + prompt)
                .filter { $0 < tokenizer.specialTokens.specialTokenBegin }
            decodeOptions.usePrefillPrompt = true
        }
        let results = try await pipe.transcribe(audioPath: fileURL.path, decodeOptions: decodeOptions)
        let transcript = results
            .map(\.text)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !transcript.isEmpty else {
            throw ReadyTypeError.transcriptionEmpty
        }

        return SpeechRecognitionCandidate(
            transcript: transcript,
            quality: Self.qualityEvidence(from: results.flatMap(\.segments))
        )
    }

    private static func qualityEvidence(from segments: [TranscriptionSegment]) -> SpeechRecognitionQualityEvidence {
        SpeechRecognitionQualityEvidenceFactory.whisper(
            segments: segments.map {
                WhisperSegmentQuality(
                    duration: Double($0.duration),
                    averageLogProbability: Double($0.avgLogprob),
                    noSpeechProbability: Double($0.noSpeechProb),
                    compressionRatio: Double($0.compressionRatio)
                )
            }
        )
    }

    private static func contextPrompt(from terms: [String]) -> String? {
        var selected: [String] = []
        var characterCount = 0

        for term in terms.prefix(80) {
            let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let additionalCount = trimmed.count + (selected.isEmpty ? 0 : 2)
            guard characterCount + additionalCount <= 500 else { break }
            selected.append(trimmed)
            characterCount += additionalCount
        }

        return selected.isEmpty ? nil : selected.joined(separator: ", ")
    }

    func prewarm() async throws {
        _ = try await pipeline(load: false, prewarm: true)
    }

    private func pipeline(load: Bool, prewarm: Bool) async throws -> WhisperKit {
        if let pipeline {
            return pipeline
        }

        guard let modelFolder = modelManager.installedModelURL() else {
            throw ReadyTypeError.transcriptionFailed("高精度语音包未安装")
        }

        let config = WhisperKitConfig(
            model: modelName,
            modelFolder: modelFolder.path,
            verbose: false,
            prewarm: prewarm,
            load: load,
            download: false
        )
        let pipe = try await WhisperKit(config)
        pipeline = pipe
        return pipe
    }
}

enum SpeechTranscriptValidator {
    static func isLikelyHallucination(_ transcript: String) -> Bool {
        let normalized = transcript
            .lowercased()
            .unicodeScalars
            .filter { !CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters).contains($0) }
            .map(String.init)
            .joined()

        guard normalized.count >= 20, normalized.count.isMultiple(of: 2) else {
            return false
        }

        let midpoint = normalized.index(normalized.startIndex, offsetBy: normalized.count / 2)
        return normalized[..<midpoint] == normalized[midpoint...]
    }
}

enum SystemSpeechRecognitionRequestFactory {
    static func make(fileURL: URL, contextualTerms: [String]) -> SFSpeechURLRecognitionRequest {
        let request = SFSpeechURLRecognitionRequest(url: fileURL)
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        request.contextualStrings = contextualTerms
        request.addsPunctuation = true
        return request
    }
}

final class SFSpeechRecognitionBackend: ContextualSpeechRecognitionBackend, SpeechRecognitionCandidateBackend {
    private let recognizers: [(localeIdentifier: String, recognizer: SFSpeechRecognizer?)]
    private let recognitionTimeout: TimeInterval
    let localeIdentifiers: [String]

    init(
        locales: [Locale] = [Locale(identifier: "zh-CN")],
        recognitionTimeout: TimeInterval = 8
    ) {
        self.localeIdentifiers = locales.map(\.identifier)
        self.recognizers = locales.map { locale in
            (locale.identifier, SFSpeechRecognizer(locale: locale))
        }
        self.recognitionTimeout = recognitionTimeout
    }

    func transcribeAudio(at fileURL: URL, contextualTerms: [String]) async throws -> String {
        try await recognizeAudio(at: fileURL, contextualTerms: contextualTerms).transcript
    }

    func recognizeAudio(at fileURL: URL, contextualTerms: [String]) async throws -> SpeechRecognitionCandidate {
        let contextualTerms = Array(contextualTerms.prefix(100))
        var bestRecognition: RecognizedSpeech?
        var failureMessages: [String] = []

        for candidate in recognizers {
            guard let recognizer = candidate.recognizer else {
                failureMessages.append("Speech recognizer is unavailable for \(candidate.localeIdentifier).")
                continue
            }

            guard recognizer.isAvailable else {
                failureMessages.append("Speech recognizer is currently unavailable for \(candidate.localeIdentifier).")
                continue
            }

            do {
                let recognition = try await recognizeAudio(
                    at: fileURL,
                    using: recognizer,
                    localeIdentifier: candidate.localeIdentifier,
                    contextualTerms: contextualTerms
                )
                let text = recognition.text.trimmingCharacters(in: .whitespacesAndNewlines)

                guard !text.isEmpty else {
                    continue
                }

                let trimmedRecognition = RecognizedSpeech(
                    text: text,
                    confidence: recognition.confidence,
                    localeIdentifier: recognition.localeIdentifier
                )

                if bestRecognition.map({ trimmedRecognition.score > $0.score }) ?? true {
                    bestRecognition = trimmedRecognition
                }
            } catch {
                failureMessages.append("\(candidate.localeIdentifier): \(Self.stableErrorDescription(for: error))")
            }
        }

        if let bestRecognition {
            let quality: SpeechRecognitionQualityEvidence
            if let confidence = bestRecognition.confidence {
                quality = .system(averageSegmentConfidence: confidence)
            } else {
                quality = .unavailable
            }
            return SpeechRecognitionCandidate(transcript: bestRecognition.text, quality: quality)
        }

        if failureMessages.isEmpty {
            throw ReadyTypeError.transcriptionEmpty
        }

        throw ReadyTypeError.transcriptionFailed(failureMessages.joined(separator: "; "))
    }

    private func recognizeAudio(
        at fileURL: URL,
        using recognizer: SFSpeechRecognizer,
        localeIdentifier: String,
        contextualTerms: [String]
    ) async throws -> RecognizedSpeech {
        let request = SystemSpeechRecognitionRequestFactory.make(
            fileURL: fileURL,
            contextualTerms: contextualTerms
        )

        return try await withCheckedThrowingContinuation { continuation in
            let gate = RecognitionResumeGate()
            var bestPartial: RecognizedSpeech?
            var task: SFSpeechRecognitionTask?

            func resumeOnce(_ result: Result<RecognizedSpeech, Error>) {
                guard gate.tryResume() else {
                    return
                }

                task?.cancel()
                continuation.resume(with: result)
            }

            task = recognizer.recognitionTask(with: request) { result, error in
                if let result {
                    let recognition = RecognizedSpeech(
                        text: result.bestTranscription.formattedString,
                        confidence: Self.averageConfidence(for: result.bestTranscription),
                        localeIdentifier: localeIdentifier
                    )

                    if bestPartial.map({ recognition.score > $0.score }) ?? true {
                        bestPartial = recognition
                    }

                    if result.isFinal {
                        resumeOnce(.success(recognition))
                        return
                    }
                }

                if let error {
                    if let bestPartial, !bestPartial.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        resumeOnce(.success(bestPartial))
                        return
                    }

                    resumeOnce(.failure(error))
                    return
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + recognitionTimeout) {
                if let bestPartial, !bestPartial.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    resumeOnce(.success(bestPartial))
                } else {
                    resumeOnce(.failure(ReadyTypeError.transcriptionFailed("\(localeIdentifier) recognition timed out.")))
                }
            }
        }
    }

    private static func averageConfidence(for transcription: SFTranscription) -> Double? {
        SpeechRecognitionQualityEvidenceFactory.systemAverageConfidence(
            transcription.segments.map { Double($0.confidence) }
        )
    }

    private static func stableErrorDescription(for error: Error) -> String {
        let nsError = error as NSError
        return "\(nsError.domain) error \(nsError.code)"
    }
}

private struct RecognizedSpeech {
    let text: String
    let confidence: Double?
    let localeIdentifier: String

    var score: Double {
        (confidence ?? 0) + min(Double(text.count) / 200, 0.2)
    }
}

private final class RecognitionResumeGate {
    private let lock = NSLock()
    private var didResume = false

    func tryResume() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard !didResume else {
            return false
        }

        didResume = true
        return true
    }
}
