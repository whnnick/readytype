import AVFoundation
import Foundation

struct AudioRecording: Equatable {
    let fileURL: URL
    let duration: TimeInterval
}

protocol AudioRecordingManaging: AnyObject {
    @discardableResult
    func startRecording() throws -> URL
    func stopRecording() throws -> AudioRecording
    func cancelRecording()
}

protocol AudioRecorderBackend: AnyObject {
    func startRecording(to fileURL: URL) throws
    func stopRecording()
}

final class AudioRecorderService: AudioRecordingManaging {
    private struct ActiveRecording {
        let fileURL: URL
        let startedAt: Date
    }

    private let backend: AudioRecorderBackend
    private let minimumDuration: TimeInterval
    private let now: () -> Date
    private let fileURLProvider: () -> URL
    private var activeRecording: ActiveRecording?

    init(
        backend: AudioRecorderBackend = AVFoundationAudioRecorderBackend(),
        minimumDuration: TimeInterval = 0.3,
        now: @escaping () -> Date = Date.init,
        fileURLProvider: @escaping () -> URL = AudioRecorderService.defaultRecordingURL
    ) {
        self.backend = backend
        self.minimumDuration = minimumDuration
        self.now = now
        self.fileURLProvider = fileURLProvider
    }

    @discardableResult
    func startRecording() throws -> URL {
        let fileURL = fileURLProvider()
        try backend.startRecording(to: fileURL)
        activeRecording = ActiveRecording(fileURL: fileURL, startedAt: now())
        return fileURL
    }

    func stopRecording() throws -> AudioRecording {
        guard let activeRecording else {
            throw ReadyTypeError.recordingFailed("No active recording.")
        }

        backend.stopRecording()
        self.activeRecording = nil

        let duration = now().timeIntervalSince(activeRecording.startedAt)
        guard duration >= minimumDuration else {
            throw ReadyTypeError.recordingTooShort
        }

        return AudioRecording(fileURL: activeRecording.fileURL, duration: duration)
    }

    func cancelRecording() {
        backend.stopRecording()
        activeRecording = nil
    }

    private static func defaultRecordingURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("readytype-\(UUID().uuidString)")
            .appendingPathExtension("m4a")
    }
}

final class AVFoundationAudioRecorderBackend: NSObject, AudioRecorderBackend {
    private var recorder: AVAudioRecorder?

    func startRecording(to fileURL: URL) throws {
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            let recorder = try AVAudioRecorder(url: fileURL, settings: settings)
            recorder.prepareToRecord()

            guard recorder.record() else {
                throw ReadyTypeError.recordingFailed("Recorder did not start.")
            }

            self.recorder = recorder
        } catch let error as ReadyTypeError {
            throw error
        } catch {
            throw ReadyTypeError.recordingFailed(error.localizedDescription)
        }
    }

    func stopRecording() {
        recorder?.stop()
        recorder = nil
    }
}
