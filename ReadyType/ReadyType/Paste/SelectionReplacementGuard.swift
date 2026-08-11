import Foundation

@MainActor
final class SelectionReplacementGuard {
    private let clipboard: ClipboardWriting
    private let activeTextContextProvider: ActiveTextContextProviding

    init(
        clipboard: ClipboardWriting,
        activeTextContextProvider: ActiveTextContextProviding
    ) {
        self.clipboard = clipboard
        self.activeTextContextProvider = activeTextContextProvider
    }

    func capture(maximumCharacterCount: Int) -> ActiveTextContextCaptureResult {
        activeTextContextProvider.capture(maximumCharacterCount: maximumCharacterCount)
    }

    func deliver(
        _ text: String,
        replacing context: ActiveTextContext,
        replaceAutomatically: Bool
    ) throws -> SelectionDeliveryResult {
        let finalText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !finalText.isEmpty else {
            throw ReadyTypeError.pasteFailed
        }

        guard replaceAutomatically else {
            try clipboard.writeString(finalText)
            return .copiedFallback(.automaticReplacementDisabled)
        }

        switch activeTextContextProvider.replaceSelectedText(finalText, ifMatching: context) {
        case .replaced:
            return .replaced
        case let .rejected(failure):
            try clipboard.writeString(finalText)
            return .copiedFallback(failure)
        }
    }
}
