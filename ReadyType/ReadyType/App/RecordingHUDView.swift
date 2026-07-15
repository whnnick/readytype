import Foundation
import SwiftUI

struct RecordingHUDView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var presentationState: RecordingHUDPresentationState
    let audioLevelProvider: () -> Double
    let onCancel: () -> Void

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
                showsEscapeHint: presentationState.isEscapeHintVisible,
                reduceMotion: preferences.reduceMotion,
                audioLevelProvider: audioLevelProvider,
                onCancel: onCancel
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 2)
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
    let showsEscapeHint: Bool
    let reduceMotion: Bool
    let audioLevelProvider: () -> Double
    let onCancel: () -> Void

    var body: some View {
        content
            .padding(.leading, 12)
            .padding(.trailing, state == .recording ? 9 : 13)
            .frame(width: MotionTokens.voiceCapsuleWidth, height: MotionTokens.voiceCapsuleHeight)
            .background(LiquidGlassCapsuleBackground())
            .overlay(alignment: .top) {
                Capsule()
                    .fill(Color.white.opacity(0.84))
                    .frame(width: 86, height: 1)
                    .padding(.top, 1)
            }
            .overlay(alignment: .bottom) {
                if isProcessing {
                    ThinkingProgressBar(
                        state: state,
                        startedAt: processingStartedAt,
                        reduceMotion: reduceMotion
                    )
                    .padding(.horizontal, 15)
                    .padding(.bottom, 4)
                    .transition(.opacity)
                }
            }
            .shadow(color: Color.black.opacity(0.17), radius: 16, x: 0, y: 8)
            .shadow(color: Color.black.opacity(0.07), radius: 4, x: 0, y: 2)
            .scaleEffect(
                MotionTokens.voiceCapsuleScale(
                    for: state,
                    preferences: MotionPreferences(reduceMotion: reduceMotion)
                )
            )
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .recording:
            HStack(spacing: 7) {
                WaveformView(
                    isActive: true,
                    reduceMotion: reduceMotion,
                    audioLevelProvider: audioLevelProvider
                )
                .frame(width: 44, height: 18)

                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.84))
                    .lineLimit(1)

                Spacer(minLength: 2)

                Text(timerText)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.black.opacity(0.52))
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                    .frame(width: 38, alignment: .trailing)

                EscapeCancelButton(
                    showsFirstUseHint: showsEscapeHint,
                    onCancel: onCancel
                )
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

private struct LiquidGlassCapsuleBackground: View {
    private let shape = RoundedRectangle(
        cornerRadius: MotionTokens.voiceCapsuleCornerRadius,
        style: .continuous
    )

    @ViewBuilder
    var body: some View {
        if #available(macOS 26.0, *) {
            shape
                .fill(Color.clear)
                .glassEffect(.regular.tint(Color.white.opacity(0.68)), in: shape)
                .overlay {
                    shape.fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.52), Color.white.opacity(0.36)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .overlay {
                    shape.stroke(Color.black.opacity(0.08), lineWidth: 0.5)
                }
        } else {
            fallbackBackground
        }
    }

    private var fallbackBackground: some View {
        shape
            .fill(.ultraThinMaterial)
            .overlay {
                shape.fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.72), Color.white.opacity(0.52)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .overlay {
                shape.stroke(Color.black.opacity(0.10), lineWidth: 0.6)
            }
            .overlay {
                shape
                    .inset(by: 1)
                    .stroke(Color.white.opacity(0.28), lineWidth: 0.5)
            }
    }
}

private struct EscapeCancelButton: View {
    let showsFirstUseHint: Bool
    let onCancel: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onCancel) {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(isHovered ? 0.12 : 0.055))
                    .overlay {
                        Circle().stroke(Color.black.opacity(0.07), lineWidth: 0.5)
                    }

                Capsule()
                    .fill(Color.black.opacity(0.52))
                    .frame(width: 9, height: 1.2)
                    .rotationEffect(.degrees(45))

                Capsule()
                    .fill(Color.black.opacity(0.52))
                    .frame(width: 9, height: 1.2)
                    .rotationEffect(.degrees(-45))
            }
            .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .accessibilityLabel("退出语音输入")
        .onHover { isHovered = $0 }
        .overlay(alignment: .topTrailing) {
            if showsFirstUseHint || isHovered {
                Text("按 Esc 退出")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.94))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.black.opacity(0.80), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .fixedSize()
                    .offset(x: 2, y: -32)
                    .transition(.opacity.combined(with: .offset(y: 3)))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .animation(.easeOut(duration: 0.12), value: showsFirstUseHint || isHovered)
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
                    ReadyTypeHUDPalette.progress,
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

    private let heightProfile: [CGFloat] = [0.48, 0.72, 0.90, 1.00, 0.78, 0.58, 0.84]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 24, paused: !isActive || reduceMotion)) { _ in
            let level = isActive && !reduceMotion ? audioLevelProvider() : 0

            HStack(alignment: .center, spacing: 3) {
                ForEach(heightProfile.indices, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(index == 3 ? ReadyTypeHUDPalette.progress : Color.black.opacity(0.58))
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
