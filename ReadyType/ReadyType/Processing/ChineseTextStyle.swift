import Foundation

enum ChineseTextStyle: String, CaseIterable, Identifiable {
    case simplified
    case traditional
    case followSystem

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .simplified:
            "简体中文"
        case .traditional:
            "繁体中文"
        case .followSystem:
            "跟随系统"
        }
    }

    fileprivate var resolved: ChineseTextStyle {
        guard self == .followSystem else { return self }

        let usesTraditionalChinese = Locale.preferredLanguages.contains { language in
            let normalized = language.lowercased()
            return normalized.contains("hant")
                || normalized.hasPrefix("zh-tw")
                || normalized.hasPrefix("zh-hk")
                || normalized.hasPrefix("zh-mo")
        }
        return usesTraditionalChinese ? .traditional : .simplified
    }
}

enum ChineseTextConverter {
    static func convert(_ text: String, style: ChineseTextStyle) -> String {
        let transform: StringTransform
        switch style.resolved {
        case .simplified:
            transform = StringTransform("Traditional-Simplified")
        case .traditional:
            transform = StringTransform("Simplified-Traditional")
        case .followSystem:
            return text
        }

        return text.applyingTransform(transform, reverse: false) ?? text
    }
}
