import Foundation

enum LocalSpeechModelReadiness {
    static func displayState(
        diskState: LocalSpeechModelState,
        runtimeState: LocalSpeechModelState
    ) -> LocalSpeechModelState {
        guard diskState == .downloadedCold else {
            return diskState
        }

        switch runtimeState {
        case .warming, .warm, .failed:
            return runtimeState
        case .notInstalled, .downloading, .downloadedCold:
            return diskState
        }
    }
}
