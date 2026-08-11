import AppKit
import ApplicationServices
import CryptoKit
import Foundation

struct TextSelectionRange: Equatable {
    let location: Int
    let length: Int
}

final class SelectionTargetReference: Equatable {
    let processIdentifier: Int32
    private let storage: Storage

    private enum Storage {
        case accessibilityElement(AXUIElement)
        case testIdentifier(String)
    }

    init(processIdentifier: Int32, testIdentifier: String) {
        self.processIdentifier = processIdentifier
        storage = .testIdentifier(testIdentifier)
    }

    fileprivate init(processIdentifier: Int32, accessibilityElement: AXUIElement) {
        self.processIdentifier = processIdentifier
        storage = .accessibilityElement(accessibilityElement)
    }

    fileprivate var accessibilityElement: AXUIElement? {
        guard case let .accessibilityElement(element) = storage else {
            return nil
        }
        return element
    }

    static func == (lhs: SelectionTargetReference, rhs: SelectionTargetReference) -> Bool {
        guard lhs.processIdentifier == rhs.processIdentifier else {
            return false
        }

        switch (lhs.storage, rhs.storage) {
        case let (.accessibilityElement(lhsElement), .accessibilityElement(rhsElement)):
            return CFEqual(lhsElement, rhsElement)
        case let (.testIdentifier(lhsIdentifier), .testIdentifier(rhsIdentifier)):
            return lhsIdentifier == rhsIdentifier
        default:
            return false
        }
    }
}

struct SelectionFingerprint: Equatable {
    let target: SelectionTargetReference
    let range: TextSelectionRange
    let selectedTextDigest: Data

    init(target: SelectionTargetReference, range: TextSelectionRange, selectedText: String) {
        self.target = target
        self.range = range
        selectedTextDigest = Data(SHA256.hash(data: Data(selectedText.utf8)))
    }

    func validationFailure(comparedTo current: SelectionFingerprint) -> SelectionValidationFailure? {
        guard target.processIdentifier == current.target.processIdentifier else {
            return .appChanged
        }
        guard target == current.target else {
            return .focusChanged
        }
        guard range == current.range,
              selectedTextDigest == current.selectedTextDigest
        else {
            return .selectionChanged
        }
        return nil
    }
}

struct ActiveTextContext: Equatable {
    let selectedText: String
    let fingerprint: SelectionFingerprint
}

enum ActiveTextContextUnavailableReason: Equatable {
    case accessibilityPermissionMissing
    case focusedElementUnavailable
    case selectionUnreadable
}

enum ActiveTextContextCaptureResult: Equatable {
    case available(ActiveTextContext)
    case noSelection
    case tooLong(characterCount: Int)
    case unavailable(ActiveTextContextUnavailableReason)
}

enum SelectionValidationFailure: Equatable {
    case appChanged
    case focusChanged
    case selectionChanged
    case selectionUnavailable
    case replacementUnsupported
    case automaticReplacementDisabled
}

enum SelectionReplacementAttempt: Equatable {
    case replaced
    case rejected(SelectionValidationFailure)
}

enum SelectionDeliveryResult: Equatable {
    case replaced
    case copiedFallback(SelectionValidationFailure)
}

@MainActor
protocol ActiveTextContextProviding: AnyObject {
    func capture(maximumCharacterCount: Int) -> ActiveTextContextCaptureResult
    func replaceSelectedText(_ text: String, ifMatching context: ActiveTextContext) -> SelectionReplacementAttempt
}

@MainActor
final class SystemActiveTextContextProvider: ActiveTextContextProviding {
    func capture(maximumCharacterCount: Int = 8_000) -> ActiveTextContextCaptureResult {
        readCurrentSelection(maximumCharacterCount: maximumCharacterCount)
    }

    func replaceSelectedText(_ text: String, ifMatching context: ActiveTextContext) -> SelectionReplacementAttempt {
        let current = readCurrentSelection(maximumCharacterCount: Int.max)
        guard case let .available(currentContext) = current else {
            return .rejected(.selectionUnavailable)
        }

        if let failure = context.fingerprint.validationFailure(comparedTo: currentContext.fingerprint) {
            return .rejected(failure)
        }

        guard let element = currentContext.fingerprint.target.accessibilityElement else {
            return .rejected(.replacementUnsupported)
        }

        let result = AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            text as CFTypeRef
        )
        return result == .success ? .replaced : .rejected(.replacementUnsupported)
    }

    private func readCurrentSelection(maximumCharacterCount: Int) -> ActiveTextContextCaptureResult {
        guard AXIsProcessTrusted() else {
            return .unavailable(.accessibilityPermissionMissing)
        }
        guard let element = focusedElement() else {
            return .unavailable(.focusedElementUnavailable)
        }

        var processIdentifier: pid_t = 0
        guard AXUIElementGetPid(element, &processIdentifier) == .success,
              let range = selectedTextRange(in: element)
        else {
            return .unavailable(.selectionUnreadable)
        }
        guard range.location >= 0, range.length > 0 else {
            return .noSelection
        }
        guard let selectedText = selectedText(in: element, range: range), !selectedText.isEmpty else {
            return .unavailable(.selectionUnreadable)
        }
        guard selectedText.count <= maximumCharacterCount else {
            return .tooLong(characterCount: selectedText.count)
        }

        let target = SelectionTargetReference(
            processIdentifier: processIdentifier,
            accessibilityElement: element
        )
        let selectionRange = TextSelectionRange(location: range.location, length: range.length)
        let context = ActiveTextContext(
            selectedText: selectedText,
            fingerprint: SelectionFingerprint(
                target: target,
                range: selectionRange,
                selectedText: selectedText
            )
        )
        return .available(context)
    }

    private func focusedElement() -> AXUIElement? {
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        ) == .success,
              let focusedValue
        else {
            return nil
        }
        return (focusedValue as! AXUIElement)
    }

    private func selectedText(in element: AXUIElement, range: CFRange) -> String? {
        if let selectedText = stringAttribute(kAXSelectedTextAttribute, in: element), !selectedText.isEmpty {
            return selectedText
        }

        guard let value = stringAttribute(kAXValueAttribute, in: element) else {
            return nil
        }
        let nsValue = value as NSString
        guard range.location <= nsValue.length,
              range.length <= nsValue.length - range.location
        else {
            return nil
        }
        return nsValue.substring(with: NSRange(location: range.location, length: range.length))
    }

    private func stringAttribute(_ attribute: String, in element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value as? String
    }

    private func selectedTextRange(in element: AXUIElement) -> CFRange? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &value
        ) == .success,
              let value,
              CFGetTypeID(value) == AXValueGetTypeID()
        else {
            return nil
        }

        let axValue = value as! AXValue
        guard AXValueGetType(axValue) == .cfRange else {
            return nil
        }
        var range = CFRange()
        return AXValueGetValue(axValue, .cfRange, &range) ? range : nil
    }
}
