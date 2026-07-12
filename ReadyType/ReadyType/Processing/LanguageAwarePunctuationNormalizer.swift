import Foundation

enum LanguageAwarePunctuationNormalizer {
    static func normalize(_ text: String) -> String {
        guard !text.isEmpty else { return text }

        return containsHanText(text)
            ? normalizeChineseText(text)
            : normalizeEnglishText(text)
    }

    private static func normalizeChineseText(_ text: String) -> String {
        let characters = Array(text)

        return String(characters.enumerated().map { index, character in
            switch character {
            case ",":
                return isBetweenDigits(characters, at: index) ? character : "，"
            case ".":
                return isWithinLatinOrNumericToken(characters, at: index) ? character : "。"
            case ":":
                return shouldPreserveASCIIColon(characters, at: index) ? character : "："
            case ";":
                return "；"
            case "?":
                return "？"
            case "!":
                return "！"
            default:
                return character
            }
        })
    }

    private static func normalizeEnglishText(_ text: String) -> String {
        let replacements: [Character: Character] = [
            "，": ",",
            "。": ".",
            "：": ":",
            "；": ";",
            "？": "?",
            "！": "!"
        ]

        return String(text.map { replacements[$0] ?? $0 })
    }

    private static func containsHanText(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF:
                true
            default:
                false
            }
        }
    }

    private static func isBetweenDigits(_ characters: [Character], at index: Int) -> Bool {
        guard index > 0, index + 1 < characters.count else { return false }
        return characters[index - 1].isNumber && characters[index + 1].isNumber
    }

    private static func isWithinLatinOrNumericToken(_ characters: [Character], at index: Int) -> Bool {
        guard index > 0, index + 1 < characters.count else { return false }
        return isLatinLetterOrNumber(characters[index - 1])
            && isLatinLetterOrNumber(characters[index + 1])
    }

    private static func shouldPreserveASCIIColon(_ characters: [Character], at index: Int) -> Bool {
        if isBetweenDigits(characters, at: index) {
            return true
        }

        guard index + 2 < characters.count else { return false }
        return characters[index + 1] == "/" && characters[index + 2] == "/"
    }

    private static func isLatinLetterOrNumber(_ character: Character) -> Bool {
        character.isNumber || character.unicodeScalars.allSatisfy { scalar in
            scalar.isASCII && CharacterSet.letters.contains(scalar)
        }
    }
}
