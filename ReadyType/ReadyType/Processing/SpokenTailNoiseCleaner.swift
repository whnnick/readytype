import Foundation

enum SpokenTailNoiseCleaner {
    static func cleanFinalOutput(_ text: String) -> String {
        cleanCommonStopWords(text).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func cleanDirectDictation(_ text: String) -> String {
        let withoutCommonStopWords = cleanCommonStopWords(text)
        let withoutPoliteClosing = removingTrailingPoliteClosing(from: withoutCommonStopWords)
        let withoutSingleGood = removingTrailingSingleGood(from: withoutPoliteClosing)
        return withoutSingleGood.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func cleanCommonStopWords(_ text: String) -> String {
        let patterns = [
            #"^(.*?[，,。.!！?？；;])\s*(OK|Ok|ok|好了|就这样|完成|结束|先这样)[。.!！]*\s*$"#,
            #"^(.*?)\s+(OK|Ok|ok|好了|就这样|完成|结束|先这样)[。.!！]*\s*$"#
        ]

        return replacingFirstMatch(in: text, patterns: patterns, with: "$1")
    }

    private static func removingTrailingSingleGood(from text: String) -> String {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedText.hasSuffix("好") else {
            return text
        }

        let body = String(trimmedText.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        guard body.count >= 12 else {
            return text
        }

        guard looksLikeDictationTaskBody(body), !looksLikeMeaningfulGoodEnding(body) else {
            return text
        }

        return body
    }

    private static func removingTrailingPoliteClosing(from text: String) -> String {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let closings = ["好谢谢大家", "好谢谢你", "好谢谢", "谢谢大家", "谢谢你", "谢谢"]

        for closing in closings {
            guard trimmedText.hasSuffix(closing) else {
                continue
            }

            let body = String(trimmedText.dropLast(closing.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            guard body.count >= 12, looksLikeDictationTaskBody(body) else {
                return text
            }

            return body
        }

        return text
    }

    private static func looksLikeDictationTaskBody(_ text: String) -> Bool {
        let actionSignals = [
            "检查", "确认", "复测", "修复", "更新", "同步", "整理", "记录", "发送", "粘贴", "输出"
        ]
        let objectSignals = [
            "流程", "保护", "说明", "文档", "日志", "事项", "权限", "打包", "测试", "结果", "配置", "语音包"
        ]

        let hasAction = actionSignals.contains { text.contains($0) }
        let hasObject = objectSignals.contains { text.contains($0) }
        return hasAction && hasObject
    }

    private static func looksLikeMeaningfulGoodEnding(_ text: String) -> Bool {
        let meaningfulSuffixes = [
            "很好", "挺好", "真好", "太好", "更好", "较好", "还好", "蛮好", "不好", "最好",
            "正好", "刚好", "准备好", "写好", "弄好", "做好", "看好", "改好", "修好",
            "整理好", "处理好", "配置好", "确认好"
        ]

        return meaningfulSuffixes.contains { text.hasSuffix($0) }
    }

    private static func replacingFirstMatch(
        in text: String,
        patterns: [String],
        with replacement: String
    ) -> String {
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else {
                continue
            }

            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            guard regex.firstMatch(in: text, range: range) != nil else {
                continue
            }

            return regex.stringByReplacingMatches(
                in: text,
                options: [],
                range: range,
                withTemplate: replacement
            )
        }

        return text
    }
}
