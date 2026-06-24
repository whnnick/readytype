import Foundation

struct SpokenOutputModeCommand: Equatable {
    var mode: OutputMode
    var transcript: String

    static func resolve(_ transcript: String, selectedMode: OutputMode) -> SpokenOutputModeCommand {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return SpokenOutputModeCommand(mode: selectedMode, transcript: trimmed)
        }

        let commands: [(mode: OutputMode, patterns: [String])] = [
            (.dictation, [
                #"^\s*(?:请)?(?:直接转文字|直接记录|原话输入)[，,。:\s]*(.*)$"#
            ]),
            (.translationToEnglish, [
                #"^\s*(?:请)?(?:把这句话)?翻译成英文[，,。:\s]*(.*)$"#
            ]),
            (.promptOutput, [
                #"^\s*(?:请)?(?:写给\s*AI|交给\s*AI)[，,。:\s]*(.*)$"#
            ]),
            (.aiCleanup, [
                #"^\s*(?:请)?(?:整理成文|整理成一段|帮我整理)[，,。:\s]*(.*)$"#
            ])
        ]

        for command in commands {
            if let cleaned = firstCapturedText(in: trimmed, patterns: command.patterns) {
                return SpokenOutputModeCommand(
                    mode: command.mode,
                    transcript: cleaned.isEmpty ? trimmed : cleaned
                )
            }
        }

        return SpokenOutputModeCommand(mode: selectedMode, transcript: transcript)
    }

    static func requiresAICapability(_ transcript: String) -> Bool {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return false
        }

        let patterns = [
            #"^\s*(?:请)?写一封"#,
            #"^\s*(?:请)?写一段"#,
            #"^\s*(?:请)?写个"#,
            #"^\s*(?:请)?帮我写"#,
            #"^\s*(?:请)?帮我把"#,
            #"^\s*(?:请)?把这句话翻译成英文"#,
            #"^\s*(?:请)?翻译成英文"#,
            #"^\s*(?:请)?写给\s*AI"#,
            #"^\s*(?:请)?交给\s*AI"#,
            #"^\s*(?:请)?整理成"#,
            #"^\s*(?:请)?帮我整理"#,
            #"^\s*(?:请)?总结"#,
            #"^\s*(?:请)?请总结"#
        ]

        return patterns.contains { pattern in
            guard let regex = try? NSRegularExpression(pattern: pattern) else {
                return false
            }
            let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
            return regex.firstMatch(in: trimmed, range: range) != nil
        }
    }

    private static func firstCapturedText(in text: String, patterns: [String]) -> String? {
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else {
                continue
            }

            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            guard
                let match = regex.firstMatch(in: text, range: range),
                match.numberOfRanges > 1,
                let captureRange = Range(match.range(at: 1), in: text)
            else {
                continue
            }

            return String(text[captureRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return nil
    }
}
