import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

enum PasteDeliveryResult: Equatable {
    case pasted
    case copiedFallback
}

protocol ClipboardWriting: AnyObject {
    func writeString(_ string: String) throws
}

protocol PasteInvoking: AnyObject {
    func invokePaste() -> Bool
}

protocol DirectTextInserting: AnyObject {
    func insert(_ text: String) -> Bool
}

@MainActor
protocol PasteTargetActivating: AnyObject {
    func captureCurrentTarget()
    func prepareForPaste() -> Bool
}

@MainActor
protocol TextDelivering: AnyObject {
    func deliver(_ text: String, pasteAutomatically: Bool) throws -> PasteDeliveryResult
}

final class PasteService: TextDelivering {
    private let clipboard: ClipboardWriting
    private let directTextInserter: DirectTextInserting
    private let pasteInvoker: PasteInvoking
    private let pasteTargetActivator: PasteTargetActivating

    init(
        clipboard: ClipboardWriting = SystemClipboard(),
        directTextInserter: DirectTextInserting = SystemFocusedTextInserter(),
        pasteInvoker: PasteInvoking = SystemPasteInvoker(),
        pasteTargetActivator: PasteTargetActivating = SystemPasteTargetActivator()
    ) {
        self.clipboard = clipboard
        self.directTextInserter = directTextInserter
        self.pasteInvoker = pasteInvoker
        self.pasteTargetActivator = pasteTargetActivator
    }

    func deliver(_ text: String, pasteAutomatically: Bool) throws -> PasteDeliveryResult {
        InjectionDiagnostics.log("deliver start pasteAutomatically=\(pasteAutomatically)")
        let finalText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !finalText.isEmpty else {
            throw ReadyTypeError.pasteFailed
        }

        guard pasteAutomatically else {
            InjectionDiagnostics.log("auto paste disabled; writing clipboard")
            try clipboard.writeString(finalText)
            return .copiedFallback
        }

        guard pasteTargetActivator.prepareForPaste() else {
            InjectionDiagnostics.log("target activation failed; writing clipboard")
            try clipboard.writeString(finalText)
            return .copiedFallback
        }

        if directTextInserter.insert(finalText) {
            InjectionDiagnostics.log("direct text insertion succeeded")
            return .pasted
        }

        InjectionDiagnostics.log("direct insertion failed; writing clipboard and invoking paste")
        try clipboard.writeString(finalText)
        return pasteInvoker.invokePaste() ? .pasted : .copiedFallback
    }
}

enum InjectionDiagnostics {
    static func log(_ message: String) {
        let line = "\(Date()) \(message)\n"
        guard let data = line.data(using: .utf8) else {
            return
        }

        let url = URL(fileURLWithPath: "/private/tmp/readytype-injection.log")
        if FileManager.default.fileExists(atPath: url.path),
           let handle = try? FileHandle(forWritingTo: url) {
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
            try? handle.close()
        } else {
            try? data.write(to: url)
        }
    }
}

final class SystemClipboard: ClipboardWriting {
    func writeString(_ string: String) throws {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        guard pasteboard.setString(string, forType: .string) else {
            throw ReadyTypeError.pasteFailed
        }
    }
}

final class SystemPasteInvoker: PasteInvoking {
    private let accessibilityTrusted: () -> Bool
    private let systemEventsPaste: () -> Bool
    private let cgEventPaste: () -> Bool

    init(
        accessibilityTrusted: @escaping () -> Bool = AXIsProcessTrusted,
        systemEventsPaste: (() -> Bool)? = nil,
        cgEventPaste: (() -> Bool)? = nil
    ) {
        self.accessibilityTrusted = accessibilityTrusted
        self.systemEventsPaste = systemEventsPaste ?? Self.invokePasteWithSystemEvents
        self.cgEventPaste = cgEventPaste ?? Self.invokePasteWithCGEvent
    }

    func invokePaste() -> Bool {
        Thread.sleep(forTimeInterval: 0.35)
        if systemEventsPaste() {
            InjectionDiagnostics.log("System Events paste succeeded")
            return true
        }

        guard accessibilityTrusted() else {
            InjectionDiagnostics.log("accessibility not trusted; paste event fallback disabled")
            return false
        }

        let result = cgEventPaste()
        InjectionDiagnostics.log("CGEvent paste result=\(result)")
        return result
    }

    private static func invokePasteWithSystemEvents() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = [
            "-e",
            #"tell application "System Events" to key code 9 using command down"#
        ]
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private static func invokePasteWithCGEvent() -> Bool {
        guard let source = CGEventSource(stateID: .hidSystemState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        else {
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.08)
        keyUp.post(tap: .cghidEventTap)
        return true
    }
}

final class SystemFocusedTextInserter: DirectTextInserting {
    func insert(_ text: String) -> Bool {
        guard AXIsProcessTrusted() else {
            InjectionDiagnostics.log("AXIsProcessTrusted=false")
            return false
        }
        InjectionDiagnostics.log("AXIsProcessTrusted=true")

        guard let element = focusedElement() else {
            InjectionDiagnostics.log("focused element unavailable")
            return false
        }

        if typeUnicodeText(text, in: element) {
            InjectionDiagnostics.log("unicode typing succeeded")
            return true
        }

        if setSelectedText(text, in: element) {
            InjectionDiagnostics.log("AX selected text set succeeded")
            return true
        }

        let result = replaceSelectedRangeWithText(text, in: element)
        InjectionDiagnostics.log("AX value replacement result=\(result)")
        return result
    }

    private func focusedElement() -> AXUIElement? {
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedElement: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        ) == .success,
              let focusedElement
        else {
            return nil
        }

        return (focusedElement as! AXUIElement)
    }

    private func typeUnicodeText(_ text: String, in element: AXUIElement) -> Bool {
        let initialValue = stringAttribute(kAXValueAttribute, in: element)

        for character in text {
            let utf16Units = Array(String(character).utf16)
            guard postUnicodeKeyEvent(utf16Units, keyDown: true),
                  postUnicodeKeyEvent(utf16Units, keyDown: false)
            else {
                InjectionDiagnostics.log("unicode event post failed")
                return false
            }

            Thread.sleep(forTimeInterval: 0.002)
        }

        Thread.sleep(forTimeInterval: 0.08)
        let changed = DirectInsertionVerification.didUnicodeTypingChangeValue(
            initialValue: initialValue,
            finalValue: stringAttribute(kAXValueAttribute, in: element)
        )
        InjectionDiagnostics.log("unicode typed AXValue changed=\(changed)")
        return changed
    }

    private func postUnicodeKeyEvent(_ utf16Units: [UniChar], keyDown: Bool) -> Bool {
        guard let source = CGEventSource(stateID: .hidSystemState),
              let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: keyDown)
        else {
            return false
        }

        utf16Units.withUnsafeBufferPointer { buffer in
            event.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: buffer.baseAddress)
        }
        event.post(tap: .cghidEventTap)
        return true
    }

    private func setSelectedText(_ text: String, in element: AXUIElement) -> Bool {
        AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            text as CFTypeRef
        ) == .success
    }

    private func replaceSelectedRangeWithText(_ text: String, in element: AXUIElement) -> Bool {
        guard let currentValue = stringAttribute(kAXValueAttribute, in: element),
              let selectedRange = selectedTextRange(in: element)
        else {
            return false
        }

        let nsValue = currentValue as NSString
        guard selectedRange.location <= nsValue.length,
              selectedRange.location + selectedRange.length <= nsValue.length
        else {
            return false
        }

        let nsRange = NSRange(location: selectedRange.location, length: selectedRange.length)
        let updatedValue = nsValue.replacingCharacters(in: nsRange, with: text)
        guard AXUIElementSetAttributeValue(
            element,
            kAXValueAttribute as CFString,
            updatedValue as CFTypeRef
        ) == .success
        else {
            return false
        }

        var cursorRange = CFRange(location: selectedRange.location + (text as NSString).length, length: 0)
        guard let cursorValue = AXValueCreate(.cfRange, &cursorRange) else {
            return true
        }

        _ = AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            cursorValue
        )
        return true
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
              let axValue = value,
              CFGetTypeID(axValue) == AXValueGetTypeID()
        else {
            return nil
        }

        let rangeValue = axValue as! AXValue
        guard AXValueGetType(rangeValue) == .cfRange else {
            return nil
        }

        var range = CFRange()
        guard AXValueGetValue(rangeValue, .cfRange, &range) else {
            return nil
        }

        return range
    }
}

enum DirectInsertionVerification {
    static func didUnicodeTypingChangeValue(initialValue: String?, finalValue: String?) -> Bool {
        guard let initialValue, let finalValue else {
            return false
        }

        return finalValue != initialValue
    }
}

@MainActor
final class SystemPasteTargetActivator: NSObject, PasteTargetActivating {
    private let workspace: NSWorkspace
    private let ownBundleIdentifier: String?
    private var lastNonReadyTypeApplication: NSRunningApplication?

    init(
        workspace: NSWorkspace = .shared,
        ownBundleIdentifier: String? = Bundle.main.bundleIdentifier
    ) {
        self.workspace = workspace
        self.ownBundleIdentifier = ownBundleIdentifier
        super.init()
        captureCurrentTarget()
    }

    func captureCurrentTarget() {
        guard let application = workspace.frontmostApplication,
              isPasteTargetCandidate(application)
        else {
            return
        }

        lastNonReadyTypeApplication = application
        InjectionDiagnostics.log("captured target \(application.localizedName ?? "unknown")")
    }

    func prepareForPaste() -> Bool {
        if let frontmostApplication = workspace.frontmostApplication,
           isPasteTargetCandidate(frontmostApplication) {
            InjectionDiagnostics.log("target already frontmost: \(workspace.frontmostApplication?.localizedName ?? "unknown")")
            return true
        }

        if isReadyType(workspace.frontmostApplication) {
            InjectionDiagnostics.log("ReadyType frontmost; hiding before paste")
            NSApp.hide(nil)
            Thread.sleep(forTimeInterval: 0.25)

            if let frontmostApplication = workspace.frontmostApplication,
               isPasteTargetCandidate(frontmostApplication) {
                return true
            }
        }

        guard let target = lastNonReadyTypeApplication, !target.isTerminated else {
            InjectionDiagnostics.log("no valid paste target available")
            return false
        }

        let activated = target.activate(options: [])
        guard activated else {
            InjectionDiagnostics.log("target activation failed: \(target.localizedName ?? "unknown")")
            return false
        }

        Thread.sleep(forTimeInterval: 0.25)
        let isReady = workspace.frontmostApplication.map(isPasteTargetCandidate) ?? false
        InjectionDiagnostics.log("target activation ready=\(isReady)")
        return isReady
    }

    private func isPasteTargetCandidate(_ application: NSRunningApplication) -> Bool {
        Self.isPasteTargetCandidate(
            bundleIdentifier: application.bundleIdentifier,
            activationPolicy: application.activationPolicy,
            isReadyType: isReadyType(application)
        )
    }

    static func isPasteTargetCandidate(
        bundleIdentifier: String?,
        activationPolicy: NSApplication.ActivationPolicy,
        isReadyType: Bool
    ) -> Bool {
        guard !isReadyType,
              activationPolicy == .regular,
              bundleIdentifier != "com.apple.loginwindow"
        else {
            return false
        }

        return true
    }

    private func isReadyType(_ application: NSRunningApplication?) -> Bool {
        guard let application else {
            return false
        }

        if let ownBundleIdentifier, application.bundleIdentifier == ownBundleIdentifier {
            return true
        }

        return application.processIdentifier == ProcessInfo.processInfo.processIdentifier
    }
}
