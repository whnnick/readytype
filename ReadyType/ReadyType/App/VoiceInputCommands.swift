import Foundation

extension Notification.Name {
    static let readyTypeToggleRecordingRequested = Notification.Name("readyTypeToggleRecordingRequested")
    static let readyTypeBeginRecordingRequested = Notification.Name("readyTypeBeginRecordingRequested")
    static let readyTypeFinishRecordingRequested = Notification.Name("readyTypeFinishRecordingRequested")
    static let readyTypeAddVocabularySuggestionRequested = Notification.Name("readyTypeAddVocabularySuggestionRequested")
    static let readyTypeIgnoreVocabularySuggestionRequested = Notification.Name("readyTypeIgnoreVocabularySuggestionRequested")
    static let readyTypeDebugInsertRequested = Notification.Name("readyTypeDebugInsertRequested")
    static let readyTypeDebugHUDRequested = Notification.Name("readyTypeDebugHUDRequested")
    static let readyTypeDebugVocabularyRequested = Notification.Name("readyTypeDebugVocabularyRequested")
}
