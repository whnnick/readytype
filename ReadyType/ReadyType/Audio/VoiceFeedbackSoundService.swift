import AVFoundation
import Foundation

@MainActor
protocol VoiceFeedbackSoundPlaying {
    func playActivationCue() async
}

@MainActor
struct NoopVoiceFeedbackSoundPlayer: VoiceFeedbackSoundPlaying {
    func playActivationCue() async {}
}

@MainActor
final class VoiceFeedbackSoundService: VoiceFeedbackSoundPlaying {
    private let sampleRate = 44_100.0
    private let duration = 0.14

    func playActivationCue() async {
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)

        guard let format,
              let buffer = makeActivationBuffer(format: format)
        else {
            return
        }

        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.22

        do {
            try engine.start()
            player.play()
            await player.scheduleBuffer(buffer)
            player.stop()
            engine.stop()
        } catch {
            engine.stop()
        }
    }

    private func makeActivationBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let samples = buffer.floatChannelData?[0]
        else {
            return nil
        }

        buffer.frameLength = frameCount
        for frame in 0 ..< Int(frameCount) {
            let time = Double(frame) / sampleRate
            let progress = time / duration
            let envelope = sin(.pi * min(max(progress, 0), 1))
            let firstTone = sin(2 * .pi * 740 * time)
            let secondTone = sin(2 * .pi * 988 * time)
            let blend = min(max((progress - 0.25) / 0.50, 0), 1)
            samples[frame] = Float((firstTone * (1 - blend) + secondTone * blend) * envelope * 0.34)
        }

        return buffer
    }
}
