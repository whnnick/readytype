import Foundation
import TelemetryDeck

@MainActor
final class TelemetryDeckAnalyticsTracker: AnalyticsTracking {
    typealias SignalSender = (String, [String: String]) -> Void

    private let send: SignalSender

    init(appID: String, send: SignalSender? = nil) {
        if let send {
            self.send = send
            return
        }

        let configuration = TelemetryDeck.Config(appID: appID)
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

    @MainActor
    static func make(bundle: Bundle = .main) -> AnalyticsTracking {
        make(appID: bundle.object(forInfoDictionaryKey: telemetryDeckAppIDKey) as? String)
    }

    @MainActor
    static func make(
        appID: String?,
        configuredTracker: (String) -> AnalyticsTracking = { TelemetryDeckAnalyticsTracker(appID: $0) }
    ) -> AnalyticsTracking {
        let trimmedAppID = appID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard UUID(uuidString: trimmedAppID) != nil else {
            return NoopAnalyticsTracker()
        }

        return configuredTracker(trimmedAppID)
    }
}
