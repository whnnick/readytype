import Foundation
@preconcurrency import WhisperKit

@MainActor
protocol LocalSpeechModelInstalling: AnyObject {
    func installModel(
        _ manifest: LocalSpeechModelManifest,
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
        guard let manifest = manager.defaultDownloadManifest() else {
            updateState(.failed(reason: "高精度语音包下载失败：缺少安装信息"))
            return state
        }
        return await downloadModel(manifest)
    }

    @discardableResult
    func downloadModel(_ manifest: LocalSpeechModelManifest) async -> LocalSpeechModelState {
        let previouslyInstalledManifest = manager.installedManifest()
        updateState(.downloading(progress: 0))

        do {
            try await installer.installModel(manifest, using: manager) { [weak self] progress in
                guard case .downloading = self?.state else {
                    return
                }

                self?.updateState(.downloading(progress: progress.clampedModelDownloadProgress))
            }

            guard manager.isUsableModel(at: manager.destinationURL(for: manifest)) else {
                throw LocalSpeechModelDownloadError.downloadDidNotProduceModel
            }

            try manager.recordInstalledManifest(manifest)
            if let previouslyInstalledManifest,
               previouslyInstalledManifest.fileName != manifest.fileName {
                try? manager.removeModel(previouslyInstalledManifest)
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

    func installModel(
        _ manifest: LocalSpeechModelManifest,
        using manager: LocalSpeechModelManager,
        progress: @escaping (Double) -> Void
    ) async throws {
        let progressReporter = ModelInstallProgressReporter(progress: progress)
        let downloadedModelURL = try await WhisperKit.download(
            variant: manifest.modelName
        ) { downloadProgress in
            Task { @MainActor in
                progressReporter.report(downloadProgress.fractionCompleted)
            }
        }

        try fileManager.createDirectory(at: manager.modelsDirectory, withIntermediateDirectories: true)
        let destinationURL = manager.destinationURL(for: manifest)
        let stagingURL = manager.modelsDirectory
            .appendingPathComponent(".\(manifest.fileName).installing-\(UUID().uuidString)")

        guard fileManager.fileExists(atPath: downloadedModelURL.path) else {
            throw LocalSpeechModelDownloadError.downloadDidNotProduceModel
        }

        try fileManager.copyItem(at: downloadedModelURL, to: stagingURL)
        guard manager.isUsableModel(at: stagingURL) else {
            try? fileManager.removeItem(at: stagingURL)
            throw LocalSpeechModelDownloadError.downloadDidNotProduceModel
        }

        guard fileManager.fileExists(atPath: destinationURL.path) else {
            try fileManager.moveItem(at: stagingURL, to: destinationURL)
            return
        }

        let backupURL = manager.modelsDirectory
            .appendingPathComponent(".\(manifest.fileName).backup-\(UUID().uuidString)")
        try fileManager.moveItem(at: destinationURL, to: backupURL)
        do {
            try fileManager.moveItem(at: stagingURL, to: destinationURL)
            try? fileManager.removeItem(at: backupURL)
        } catch {
            if !fileManager.fileExists(atPath: destinationURL.path) {
                try? fileManager.moveItem(at: backupURL, to: destinationURL)
            }
            throw error
        }
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
