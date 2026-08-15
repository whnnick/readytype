import Foundation

enum SpeechRecognitionQualityEvidence: Equatable, Sendable {
    case system(averageSegmentConfidence: Double)
    case whisper(
        averageLogProbability: Double,
        maximumNoSpeechProbability: Double,
        maximumCompressionRatio: Double
    )
    case unavailable
}

struct SpeechRecognitionCandidate: Equatable, Sendable {
    let transcript: String
    let quality: SpeechRecognitionQualityEvidence

    init(transcript: String, quality: SpeechRecognitionQualityEvidence = .unavailable) {
        self.transcript = transcript
        self.quality = quality
    }
}

struct WhisperSegmentQuality: Equatable, Sendable {
    let duration: Double
    let averageLogProbability: Double
    let noSpeechProbability: Double
    let compressionRatio: Double
}

enum SpeechRecognitionQualityEvidenceFactory {
    static func systemAverageConfidence(_ values: [Double]) -> Double? {
        let positiveValues = values.filter { $0 > 0 }
        guard !positiveValues.isEmpty else {
            return nil
        }
        return positiveValues.reduce(0, +) / Double(positiveValues.count)
    }

    static func whisper(segments: [WhisperSegmentQuality]) -> SpeechRecognitionQualityEvidence {
        guard !segments.isEmpty else {
            return .unavailable
        }

        let weights = segments.map { max($0.duration, 0.001) }
        let totalWeight = weights.reduce(0, +)
        let weightedLogProbability = zip(segments, weights)
            .reduce(0) { $0 + $1.0.averageLogProbability * $1.1 }
            / totalWeight

        return .whisper(
            averageLogProbability: weightedLogProbability,
            maximumNoSpeechProbability: segments.map(\.noSpeechProbability).max() ?? 0,
            maximumCompressionRatio: segments.map(\.compressionRatio).max() ?? 1
        )
    }
}

struct SpeechRecognitionCandidateSelection: Equatable {
    let backend: SpeechRecognitionBackendSelection
    let candidate: SpeechRecognitionCandidate
}

struct SpeechRecognitionCandidateSelector {
    private let minimumSystemConfidence = 0.35
    private let lowSystemConfidence = 0.55
    private let strongWhisperLogProbability = -0.5
    private let maximumStrongWhisperNoSpeechProbability = 0.3
    private let maximumStrongWhisperCompressionRatio = 1.8
    private let minimumWhisperLogProbability = -1.0
    private let maximumWhisperNoSpeechProbability = 0.6
    private let maximumWhisperCompressionRatio = 2.4

    func select(
        fastSystem: SpeechRecognitionCandidate?,
        highAccuracy: SpeechRecognitionCandidate?,
        deadlineReached: Bool
    ) -> SpeechRecognitionCandidateSelection? {
        let acceptableFast = fastSystem.flatMap { isAcceptable($0) ? $0 : nil }
        let acceptableHigh = highAccuracy.flatMap { isAcceptable($0) ? $0 : nil }

        if let acceptableFast, let acceptableHigh {
            if hasClearHighAccuracyAdvantage(acceptableHigh)
                || hasLowSystemConfidence(acceptableFast) {
                return SpeechRecognitionCandidateSelection(backend: .highAccuracyLocal, candidate: acceptableHigh)
            }
            return SpeechRecognitionCandidateSelection(backend: .fastSystem, candidate: acceptableFast)
        }

        if let acceptableHigh,
           fastSystem != nil || deadlineReached || hasClearHighAccuracyAdvantage(acceptableHigh) {
            return SpeechRecognitionCandidateSelection(backend: .highAccuracyLocal, candidate: acceptableHigh)
        }

        if let acceptableFast, highAccuracy != nil || deadlineReached {
            return SpeechRecognitionCandidateSelection(backend: .fastSystem, candidate: acceptableFast)
        }

        if deadlineReached, let fastSystem, isStructurallyUsable(fastSystem) {
            return SpeechRecognitionCandidateSelection(backend: .fastSystem, candidate: fastSystem)
        }

        return nil
    }

    private func isStructurallyUsable(_ candidate: SpeechRecognitionCandidate) -> Bool {
        let transcript = candidate.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        return !transcript.isEmpty && !SpeechTranscriptValidator.isLikelyHallucination(transcript)
    }

    private func isAcceptable(_ candidate: SpeechRecognitionCandidate) -> Bool {
        guard isStructurallyUsable(candidate) else {
            return false
        }

        switch candidate.quality {
        case let .system(averageSegmentConfidence):
            return averageSegmentConfidence >= minimumSystemConfidence
        case let .whisper(averageLogProbability, maximumNoSpeechProbability, maximumCompressionRatio):
            return averageLogProbability >= minimumWhisperLogProbability
                && maximumNoSpeechProbability <= maximumWhisperNoSpeechProbability
                && maximumCompressionRatio <= maximumWhisperCompressionRatio
        case .unavailable:
            return true
        }
    }

    private func hasLowSystemConfidence(_ candidate: SpeechRecognitionCandidate) -> Bool {
        guard case let .system(averageSegmentConfidence) = candidate.quality else {
            return false
        }
        return averageSegmentConfidence < lowSystemConfidence
    }

    private func hasClearHighAccuracyAdvantage(_ candidate: SpeechRecognitionCandidate) -> Bool {
        guard case let .whisper(
            averageLogProbability,
            maximumNoSpeechProbability,
            maximumCompressionRatio
        ) = candidate.quality else {
            return false
        }

        return averageLogProbability >= strongWhisperLogProbability
            && maximumNoSpeechProbability <= maximumStrongWhisperNoSpeechProbability
            && maximumCompressionRatio <= maximumStrongWhisperCompressionRatio
    }
}
