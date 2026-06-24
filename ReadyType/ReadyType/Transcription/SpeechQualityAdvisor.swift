import Foundation

struct SpeechQualityAdvisoryRequest: Equatable {
    var transcript: String
    var recognitionMode: SpeechRecognitionMode
    var isHighAccuracyRecognitionEnabled: Bool
    var localSpeechModelState: LocalSpeechModelState
}

struct SpeechQualityAdvisory: Equatable {
    var message: String
}

enum SpeechQualityAdvisor {
    static func advisory(for request: SpeechQualityAdvisoryRequest) -> SpeechQualityAdvisory? {
        guard shouldSuggestHighAccuracy(for: request) else {
            return nil
        }

        return SpeechQualityAdvisory(
            message: "识别结果偏英文；如果你刚才说的是中文，可在设置中启用更准确的本机识别。"
        )
    }

    private static func shouldSuggestHighAccuracy(for request: SpeechQualityAdvisoryRequest) -> Bool {
        guard request.localSpeechModelState != .warm else {
            return false
        }

        guard request.recognitionMode != .highAccuracyLocal || !request.isHighAccuracyRecognitionEnabled else {
            return false
        }

        let profile = TranscriptScriptProfile(transcript: request.transcript)
        return profile.isLatinHeavyWithoutChinese
    }
}

private struct TranscriptScriptProfile {
    let hanCharacterCount: Int
    let latinLetterCount: Int
    let visibleCharacterCount: Int
    let wordCount: Int

    init(transcript: String) {
        var hanCharacterCount = 0
        var latinLetterCount = 0
        var visibleCharacterCount = 0

        for scalar in transcript.unicodeScalars {
            if CharacterSet.whitespacesAndNewlines.contains(scalar) {
                continue
            }

            visibleCharacterCount += 1

            if Self.isHan(scalar) {
                hanCharacterCount += 1
            } else if Self.isLatinLetter(scalar) {
                latinLetterCount += 1
            }
        }

        self.hanCharacterCount = hanCharacterCount
        self.latinLetterCount = latinLetterCount
        self.visibleCharacterCount = visibleCharacterCount
        self.wordCount = transcript
            .split { $0.isWhitespace || $0.isPunctuation }
            .count
    }

    var isLatinHeavyWithoutChinese: Bool {
        guard hanCharacterCount == 0,
              latinLetterCount >= 18,
              wordCount >= 5,
              visibleCharacterCount > 0
        else {
            return false
        }

        return Double(latinLetterCount) / Double(visibleCharacterCount) >= 0.72
    }

    private static func isHan(_ scalar: UnicodeScalar) -> Bool {
        (0x4E00...0x9FFF).contains(Int(scalar.value)) ||
            (0x3400...0x4DBF).contains(Int(scalar.value)) ||
            (0x20000...0x2A6DF).contains(Int(scalar.value))
    }

    private static func isLatinLetter(_ scalar: UnicodeScalar) -> Bool {
        (0x0041...0x005A).contains(Int(scalar.value)) ||
            (0x0061...0x007A).contains(Int(scalar.value))
    }
}
