import Foundation
import TelemetryDeck

@MainActor
final class TelemetryDeckAnalyticsTracker: AnalyticsTracking {
    typealias SignalSender = (String, [String: String]) -> Void

    private let send: SignalSender

    init(appID: String, testMode: Bool = false, send: SignalSender? = nil) {
        if let send {
            self.send = send
            return
        }

        let configuration = TelemetryDeck.Config(appID: appID)
        configuration.testMode = testMode
        configuration.sendNewSessionBeganSignal = false
        configuration.sessionStatsEnabled = false
        configuration.logHandler = nil
        TelemetryDeck.initialize(config: configuration)
        self.send = { name, parameters in
            TelemetryDeck.signal(name, parameters: parameters)
        }
    }

    func track(_ event: ReadyTypeAnalyticsEvent) {
        let signal = event.signal
        send(signal.name, signal.parameters)
    }
}

enum ReadyTypeAnalyticsFactory {
    static let telemetryDeckAppIDKey = "ReadyTypeTelemetryDeckAppID"
    static let telemetryDeckTestModeKey = "ReadyTypeTelemetryDeckTestMode"

    @MainActor
    static func make(bundle: Bundle = .main) -> AnalyticsTracking {
        make(
            appID: bundle.object(forInfoDictionaryKey: telemetryDeckAppIDKey) as? String,
            testMode: bundle.object(forInfoDictionaryKey: telemetryDeckTestModeKey) as? Bool ?? false
        )
    }

    @MainActor
    static func make(
        appID: String?,
        testMode: Bool = false,
        configuredTracker: (String, Bool) -> AnalyticsTracking = {
            TelemetryDeckAnalyticsTracker(appID: $0, testMode: $1)
        }
    ) -> AnalyticsTracking {
        let trimmedAppID = appID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard UUID(uuidString: trimmedAppID) != nil else {
            return NoopAnalyticsTracker()
        }

        return configuredTracker(trimmedAppID, testMode)
    }
}
