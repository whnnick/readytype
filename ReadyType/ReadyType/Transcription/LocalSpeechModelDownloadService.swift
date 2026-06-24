import Foundation
@preconcurrency import WhisperKit

@MainActor
protocol LocalSpeechModelInstalling: AnyObject {
    func installDefaultModel(
        using manager: LocalSpeechModelManager,
        progress: @escaping (Double) -> Void
    ) async throws
}

@MainActor
final class LocalSpeechModelDownloadService {
    private(set) var state: LocalSpeechModelState

    private let manager: LocalSpeechModelManager
    private let installer: LocalSpeechModelInstalling
    private let onStateChange: ((LocalSpeechModelState) -> Void)?

    init(
        manager: LocalSpeechModelManager = LocalSpeechModelManager(),
        installer: LocalSpeechModelInstalling = CoreMLSpeechModelInstaller(),
        onStateChange: ((LocalSpeechModelState) -> Void)? = nil
    ) {
        self.manager = manager
        self.installer = installer
        self.onStateChange = onStateChange
        self.state = manager.state()
    }

    @discardableResult
    func downloadDefaultModel() async -> LocalSpeechModelState {
        updateState(.downloading(progress: 0))

        do {
            try await installer.installDefaultModel(using: manager) { [weak self] progress in
                guard case .downloading = self?.state else {
                    return
                }

                self?.updateState(.downloading(progress: progress.clampedModelDownloadProgress))
            }
            let installedState = manager.state()
            updateState(installedState)
            return installedState
        } catch {
            updateState(.failed(reason: readableDownloadFailure(error)))
            return state
        }
    }

    private func updateState(_ newState: LocalSpeechModelState) {
        state = newState
        onStateChange?(newState)
    }

    private func readableDownloadFailure(_ error: Error) -> String {
        if let readyTypeError = error as? LocalSpeechModelDownloadError {
            return readyTypeError.userMessage
        }

        return "高精度语音包下载失败：\(error.localizedDescription)"
    }
}

enum LocalSpeechModelDownloadError: Error, Equatable {
    case downloadDidNotProduceModel

    var userMessage: String {
        switch self {
        case .downloadDidNotProduceModel:
            "高精度语音包下载失败：未生成模型目录"
        }
    }
}

final class CoreMLSpeechModelInstaller: LocalSpeechModelInstalling {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func installDefaultModel(
        using manager: LocalSpeechModelManager,
        progress: @escaping (Double) -> Void
    ) async throws {
        let progressReporter = ModelInstallProgressReporter(progress: progress)
        let downloadedModelURL = try await WhisperKit.download(
            variant: LocalSpeechModelManager.defaultWhisperKitModelName
        ) { downloadProgress in
            Task { @MainActor in
                progressReporter.report(downloadProgress.fractionCompleted)
            }
        }

        try fileManager.createDirectory(at: manager.modelsDirectory, withIntermediateDirectories: true)
        let destinationURL = manager.destinationURL(for: LocalSpeechModelManifest(fileName: LocalSpeechModelManager.defaultWhisperKitModelFolderName))

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        guard fileManager.fileExists(atPath: downloadedModelURL.path) else {
            throw LocalSpeechModelDownloadError.downloadDidNotProduceModel
        }

        try fileManager.copyItem(at: downloadedModelURL, to: destinationURL)
    }
}

@MainActor
private final class ModelInstallProgressReporter {
    private let progress: (Double) -> Void

    init(progress: @escaping (Double) -> Void) {
        self.progress = progress
    }

    func report(_ value: Double) {
        progress(value)
    }
}

private extension Double {
    var clampedModelDownloadProgress: Double {
        min(max(self, 0), 1)
    }
}
