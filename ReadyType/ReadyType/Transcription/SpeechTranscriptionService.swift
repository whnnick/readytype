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

    init(
        router: SpeechRecognitionRouter = SpeechRecognitionRouter(),
        fastSystemBackend: SpeechRecognitionBackend = FastSystemSpeechBackend(),
        highAccuracyBackend: SpeechRecognitionBackend = LocalHighAccuracySpeechBackend(),
        contextProvider: @escaping ContextProvider = RoutedSpeechRecognitionBackend.defaultContext,
        onDecision: DecisionObserver? = nil,
        automaticHighAccuracyTimeout: Duration = .seconds(6)
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
            do {
                return try await transcribeWithHighAccuracy(recording: recording, mode: context.mode)
            } catch AutomaticHighAccuracyTimeoutError.timedOut {
                onDecision?(
                    SpeechRecognitionRouteDecision(
                        backend: .fastSystem,
                        fallbackReason: "高精度识别等待过久，已使用极速识别。"
                    )
                )
                return try await transcribeWithFastSystem(recording: recording, contextualTerms: context.contextualTerms)
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

    private func transcribeWithHighAccuracy(recording: AudioRecording, mode: SpeechRecognitionMode) async throws -> String {
        guard mode == .automatic else {
            return try await highAccuracyBackend.transcribeAudio(at: recording.fileURL)
        }

        return try await transcribeAutomaticHighAccuracy(recording: recording)
    }

    private func transcribeAutomaticHighAccuracy(recording: AudioRecording) async throws -> String {
        let stream = AsyncStream<Result<String, Error>> { continuation in
            let recognitionTask = Task { @MainActor in
                do {
                    let transcript = try await highAccuracyBackend.transcribeAudio(at: recording.fileURL)
                    continuation.yield(.success(transcript))
                } catch is CancellationError {
                    return
                } catch {
                    continuation.yield(.failure(error))
                }
                continuation.finish()
            }

            let timeoutTask = Task {
                do {
                    try await Task.sleep(for: automaticHighAccuracyTimeout)
                    continuation.yield(.failure(AutomaticHighAccuracyTimeoutError.timedOut))
                    continuation.finish()
                } catch {
                    return
                }
            }

            continuation.onTermination = { _ in
                recognitionTask.cancel()
                timeoutTask.cancel()
            }
        }

        for await result in stream {
            return try result.get()
        }

        throw ReadyTypeError.transcriptionFailed("高精度识别未返回结果")
    }

    private func transcribeWithFastSystem(recording: AudioRecording, contextualTerms: [String]) async throws -> String {
        let cappedTerms = Array(contextualTerms.prefix(100))

        if let contextualBackend = fastSystemBackend as? ContextualSpeechRecognitionBackend {
            return try await contextualBackend.transcribeAudio(at: recording.fileURL, contextualTerms: cappedTerms)
        }

        return try await fastSystemBackend.transcribeAudio(at: recording.fileURL)
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

private enum AutomaticHighAccuracyTimeoutError: Error {
    case timedOut
}

final class FastSystemSpeechBackend: ContextualSpeechRecognitionBackend {
    private let systemSpeechBackend: SpeechRecognitionBackend

    init(systemSpeechBackend: SpeechRecognitionBackend = SFSpeechRecognitionBackend()) {
        self.systemSpeechBackend = systemSpeechBackend
    }

    func transcribeAudio(at fileURL: URL, contextualTerms: [String]) async throws -> String {
        if let contextualBackend = systemSpeechBackend as? ContextualSpeechRecognitionBackend {
            return try await contextualBackend.transcribeAudio(at: fileURL, contextualTerms: contextualTerms)
        }

        return try await systemSpeechBackend.transcribeAudio(at: fileURL)
    }
}

enum LocalHighAccuracySpeechEngineKind: Equatable {
    case whisperKit
}

@MainActor
protocol LocalHighAccuracySpeechEngine: AnyObject {
    func transcribeAudio(at fileURL: URL) async throws -> String
    func prewarm() async throws
}

final class LocalHighAccuracySpeechBackend: SpeechRecognitionBackend {
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
}

final class CoreMLHighAccuracySpeechEngine: LocalHighAccuracySpeechEngine {
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
        let pipe = try await pipeline(load: true, prewarm: false)
        let decodeOptions = DecodingOptions(language: "zh", chunkingStrategy: .vad)
        let results = try await pipe.transcribe(audioPath: fileURL.path, decodeOptions: decodeOptions)
        let transcript = results
            .map(\.text)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !transcript.isEmpty else {
            throw ReadyTypeError.transcriptionEmpty
        }

        return transcript
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

final class SFSpeechRecognitionBackend: ContextualSpeechRecognitionBackend {
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
            return bestRecognition.text
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
        let request = SFSpeechURLRecognitionRequest(url: fileURL)
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        request.contextualStrings = contextualTerms

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

    private static func averageConfidence(for transcription: SFTranscription) -> Double {
        let confidenceValues = transcription.segments
            .map(\.confidence)
            .filter { $0 > 0 }

        guard !confidenceValues.isEmpty else {
            return 0
        }

        let total = confidenceValues.reduce(Float(0), +)
        return Double(total / Float(confidenceValues.count))
    }

    private static func stableErrorDescription(for error: Error) -> String {
        let nsError = error as NSError
        return "\(nsError.domain) error \(nsError.code)"
    }
}

private struct RecognizedSpeech {
    let text: String
    let confidence: Double
    let localeIdentifier: String

    var score: Double {
        confidence + min(Double(text.count) / 200, 0.2)
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
