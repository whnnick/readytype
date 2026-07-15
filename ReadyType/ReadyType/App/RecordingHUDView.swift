import Foundation
import SwiftUI

struct RecordingHUDView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var presentationState: RecordingHUDPresentationState
    let audioLevelProvider: () -> Double

    @State private var errorOffset: CGFloat = 0
    private var preferences: MotionPreferences { .current }

    var body: some View {
        TimelineView(.periodic(from: presentationState.recordingStartedAt, by: 1)) { timeline in
            let presentation = VoiceInputHUDText.presentation(
                for: appState.runtimeState,
                shortcut: appState.voiceShortcut
            )

            UnifiedVoiceCapsule(
                state: appState.runtimeState,
                title: presentation.title,
                timerText: timerText(at: timeline.date),
                processingStartedAt: presentationState.processingStartedAt,
                reduceMotion: preferences.reduceMotion,
                audioLevelProvider: audioLevelProvider
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .offset(x: errorOffset)
            .animation(MotionTokens.crossfadeAnimation(for: preferences), value: presentation)
            .animation(MotionTokens.statusAnimation(for: preferences), value: appState.runtimeState)
            .onChange(of: appState.runtimeState) { _, state in
                guard case .error = state,
                      MotionTokens.errorShakeEnabled(for: preferences)
                else {
                    return
                }

                withAnimation(.linear(duration: 0.055).repeatCount(5, autoreverses: true)) {
                    errorOffset = 7
                }

                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(330))
                    errorOffset = 0
                }
            }
        }
    }

    private func timerText(at date: Date) -> String {
        guard appState.runtimeState == .recording else {
            return "00:00"
        }

        let elapsed = max(0, Int(date.timeIntervalSince(presentationState.recordingStartedAt)))
        return String(format: "%02d:%02d", elapsed / 60, elapsed % 60)
    }
}

private struct UnifiedVoiceCapsule: View {
    let state: RuntimeState
    let title: String
    let timerText: String
    let processingStartedAt: Date
    let reduceMotion: Bool
    let audioLevelProvider: () -> Double

    var body: some View {
        content
            .padding(.horizontal, 13)
            .frame(width: MotionTokens.voiceCapsuleWidth, height: MotionTokens.voiceCapsuleHeight)
            .background(
                Color.white.opacity(0.98),
                in: RoundedRectangle(cornerRadius: MotionTokens.voiceCapsuleCornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: MotionTokens.voiceCapsuleCornerRadius, style: .continuous)
                    .stroke(Color.black.opacity(0.11), lineWidth: 0.6)
            )
            .overlay(alignment: .top) {
                Capsule()
                    .fill(Color.white)
                    .frame(width: 96, height: 1)
                    .padding(.top, 1)
            }
            .overlay(alignment: .bottom) {
                if isProcessing {
                    ThinkingProgressBar(
                        state: state,
                        startedAt: processingStartedAt,
                        reduceMotion: reduceMotion
                    )
                    .padding(.horizontal, 14)
                    .padding(.bottom, 4)
                    .transition(.opacity)
                }
            }
            .shadow(color: Color.black.opacity(0.18), radius: 16, x: 0, y: 8)
            .scaleEffect(MotionTokens.voiceCapsuleScale(for: state, preferences: MotionPreferences(reduceMotion: reduceMotion)))
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .recording:
            HStack(spacing: 9) {
                WaveformView(
                    isActive: true,
                    reduceMotion: reduceMotion,
                    audioLevelProvider: audioLevelProvider
                )
                .frame(width: 50, height: 18)

                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.84))
                    .lineLimit(1)

                Spacer(minLength: 2)

                Text(timerText)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.black.opacity(0.52))
                    .frame(width: 38, alignment: .trailing)
            }
        case .transcribing, .processingAI:
            HStack(spacing: 8) {
                ThinkingIndicator(reduceMotion: reduceMotion)

                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.84))
                    .lineLimit(1)
                    .contentTransition(.opacity)
            }
            .padding(.bottom, 3)
        case .pasted:
            FeedbackContent(symbol: "checkmark", title: title, tint: ReadyTypeHUDPalette.success)
        case .copiedFallback:
            FeedbackContent(symbol: "doc.on.clipboard", title: title, tint: ReadyTypeHUDPalette.warning)
        case .error:
            FeedbackContent(symbol: "exclamationmark", title: title, tint: ReadyTypeHUDPalette.danger)
        case .idle:
            FeedbackContent(symbol: "waveform", title: title, tint: Color.black.opacity(0.62))
        }
    }

    private var isProcessing: Bool {
        state == .transcribing || state == .processingAI
    }
}

private struct FeedbackContent: View {
    let symbol: String
    let title: String
    let tint: Color

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 18, height: 18)

            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.black.opacity(0.84))
                .lineLimit(1)
                .contentTransition(.opacity)
        }
    }
}

private struct ThinkingIndicator: View {
    let reduceMotion: Bool

    @State private var isRotating = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.black.opacity(0.10), lineWidth: 1.5)

            Circle()
                .trim(from: 0.08, to: 0.72)
                .stroke(
                    Color.black.opacity(0.72),
                    style: StrokeStyle(lineWidth: 1.8, lineCap: .round)
                )
                .rotationEffect(.degrees(isRotating ? 360 : 0))
        }
        .frame(width: 14, height: 14)
        .onAppear {
            guard !reduceMotion else {
                return
            }

            withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                isRotating = true
            }
        }
    }
}

private struct ThinkingProgressBar: View {
    let state: RuntimeState
    let startedAt: Date
    let reduceMotion: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.black.opacity(0.07))

                    Capsule()
                        .fill(ReadyTypeHUDPalette.progress)
                        .frame(width: proxy.size.width * progress(at: timeline.date))
                }
            }
        }
        .frame(height: 2)
        .accessibilityHidden(true)
    }

    private func progress(at date: Date) -> CGFloat {
        let elapsed = max(0, date.timeIntervalSince(startedAt))
        let range: (start: Double, end: Double, duration: Double)

        switch state {
        case .transcribing:
            range = (0.08, 0.58, 1.4)
        case .processingAI:
            range = (0.60, 0.94, 2.2)
        default:
            return 0
        }

        if reduceMotion {
            return CGFloat(range.start)
        }

        let eased = 1 - exp(-elapsed * 2.4 / range.duration)
        return CGFloat(range.start + (range.end - range.start) * eased)
    }
}

private enum ReadyTypeHUDPalette {
    static let progress = Color(red: 0.25, green: 0.62, blue: 0.42)
    static let success = Color(red: 0.18, green: 0.56, blue: 0.36)
    static let warning = Color(red: 0.84, green: 0.55, blue: 0.18)
    static let danger = Color(red: 0.78, green: 0.27, blue: 0.24)
}

private struct WaveformView: View {
    let isActive: Bool
    let reduceMotion: Bool
    let audioLevelProvider: () -> Double

    private let heightProfile: [CGFloat] = [0.48, 0.72, 0.90, 0.66, 1.00, 0.78, 0.58, 0.84]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 24, paused: !isActive || reduceMotion)) { _ in
            let level = isActive && !reduceMotion ? audioLevelProvider() : 0

            HStack(alignment: .center, spacing: 3) {
                ForEach(heightProfile.indices, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(index == 4 ? ReadyTypeHUDPalette.progress : Color.black.opacity(0.62))
                        .frame(width: 3, height: height(for: index, level: level))
                        .opacity(isActive ? 0.95 : 0.30)
                }
            }
        }
    }

    private func height(for index: Int, level: Double) -> CGFloat {
        guard isActive,
              !reduceMotion,
              MotionTokens.waveAnimationEnabled(for: MotionPreferences(reduceMotion: reduceMotion))
        else {
            return 6
        }

        let clampedLevel = CGFloat(min(max(level, 0), 1))
        return 4 + clampedLevel * 14 * heightProfile[index]
    }
}
