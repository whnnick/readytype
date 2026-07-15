import SwiftUI

struct RecordingHUDView: View {
    @ObservedObject var appState: AppState
    let recordingStartedAt: Date
    let audioLevelProvider: () -> Double

    @State private var errorOffset: CGFloat = 0
    @AppStorage("readyTypeAppearance") private var appearanceRawValue = ReadyTypeAppearance.system.rawValue
    private var preferences: MotionPreferences { .current }

    var body: some View {
        TimelineView(.periodic(from: recordingStartedAt, by: 1)) { timeline in
            let presentation = VoiceInputHUDText.presentation(
                for: appState.runtimeState,
                shortcut: appState.voiceShortcut
            )

            Group {
                if MotionTokens.usesMinimalProcessingCapsule(for: appState.runtimeState) {
                    ProcessingCapsule(
                        title: presentation.title,
                        reduceMotion: preferences.reduceMotion
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                } else {
                    standardCapsule(presentation: presentation, date: timeline.date)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
            }
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
        .preferredColorScheme(appearance.colorScheme)
    }

    private func standardCapsule(
        presentation: VoiceInputHUDPresentation,
        date: Date
    ) -> some View {
        HStack(spacing: 10) {
            VoiceCapsuleStatusLight(role: appState.runtimeState.readyTypeStatusRole)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(presentation.title)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)
                        .contentTransition(.opacity)
                        .foregroundStyle(ReadyTypeTheme.ink)

                    VoiceCapsuleBadge(text: appState.selectedMode.displayName, role: appState.runtimeState.readyTypeStatusRole)
                }

                Text(presentation.subtitle)
                    .font(.system(size: 11, weight: .regular))
                    .lineLimit(1)
                    .foregroundStyle(ReadyTypeTheme.muted)
                    .contentTransition(.opacity)
            }

            Spacer(minLength: 4)

            Text(timerText(at: date))
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(appState.runtimeState == .recording ? ReadyTypeTheme.ink : ReadyTypeTheme.muted)
                .frame(width: 42, alignment: .trailing)

            WaveformView(
                isActive: appState.runtimeState == .recording,
                reduceMotion: preferences.reduceMotion,
                audioLevelProvider: audioLevelProvider
            )
            .frame(width: 58, height: 20)
        }
        .frame(height: MotionTokens.voiceCapsuleHeight)
        .padding(.horizontal, 14)
        .background {
            RoundedRectangle(cornerRadius: MotionTokens.voiceCapsuleCornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: MotionTokens.voiceCapsuleCornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            ReadyTypeTheme.fieldStrong.opacity(0.44),
                            ReadyTypeTheme.field.opacity(0.30)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay(
            VoiceCapsuleFlowBorder(
                state: appState.runtimeState,
                preferences: preferences
            )
        )
        .overlay(alignment: .topLeading) {
            Capsule()
                .fill(ReadyTypeTheme.ink.opacity(0.16))
                .frame(width: 112, height: 1)
                .padding(.leading, 22)
                .padding(.top, 1)
        }
        .shadow(color: Color.black.opacity(0.22), radius: 18, x: 0, y: 10)
        .shadow(
            color: ReadyTypeTheme.color(for: appState.runtimeState.readyTypeStatusRole).opacity(
                MotionTokens.voiceCapsuleGlowOpacity(for: appState.runtimeState, preferences: preferences)
            ),
            radius: 24,
            x: 0,
            y: 10
        )
        .scaleEffect(MotionTokens.voiceCapsuleScale(for: appState.runtimeState, preferences: preferences))
    }

    private var appearance: ReadyTypeAppearance {
        ReadyTypeAppearance(rawValue: appearanceRawValue) ?? .system
    }

    private func timerText(at date: Date) -> String {
        guard appState.runtimeState == .recording else {
            return "00:00"
        }

        let elapsed = max(0, Int(date.timeIntervalSince(recordingStartedAt)))
        return String(format: "%02d:%02d", elapsed / 60, elapsed % 60)
    }
}

private struct ProcessingCapsule: View {
    let title: String
    let reduceMotion: Bool

    @State private var isRotating = false

    var body: some View {
        HStack(spacing: 10) {
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

            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.black.opacity(0.84))
                .lineLimit(1)
                .contentTransition(.opacity)
        }
        .padding(.horizontal, 12)
        .frame(width: MotionTokens.processingCapsuleWidth, height: MotionTokens.processingCapsuleHeight)
        .background(
            Color.white.opacity(0.97),
            in: RoundedRectangle(cornerRadius: MotionTokens.processingCapsuleHeight / 2, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: MotionTokens.processingCapsuleHeight / 2, style: .continuous)
                .stroke(Color.black.opacity(0.10), lineWidth: 0.6)
        )
        .overlay(alignment: .top) {
            Capsule()
                .fill(Color.white.opacity(0.92))
                .frame(width: 92, height: 1)
                .padding(.top, 1)
        }
        .shadow(color: Color.black.opacity(0.18), radius: 16, x: 0, y: 8)
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

private struct VoiceCapsuleFlowBorder: View {
    let state: RuntimeState
    let preferences: MotionPreferences

    @State private var sweepPhase = false
    @State private var errorPulse = false

    private var role: StatusRole {
        state.readyTypeStatusRole
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                baseBorder

                if MotionTokens.voiceCapsuleFlowEnabled(for: state, preferences: preferences) {
                    horizontalSweep(in: proxy.size)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .padding(.top, 1)
                }

                if MotionTokens.voiceCapsuleErrorPulseEnabled(for: state, preferences: preferences) {
                    errorPulseBorder
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .allowsHitTesting(false)
        .onAppear {
            restartMotion()
        }
        .onChange(of: state) { _, _ in
            restartMotion()
        }
    }

    private var baseBorder: some View {
        RoundedRectangle(cornerRadius: MotionTokens.voiceCapsuleCornerRadius, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [
                        ReadyTypeTheme.ink.opacity(0.20),
                        ReadyTypeTheme.color(for: role).opacity(0.34),
                        ReadyTypeTheme.strokeSoft.opacity(0.42)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 0.6
            )
    }

    private var errorPulseBorder: some View {
        RoundedRectangle(cornerRadius: MotionTokens.voiceCapsuleCornerRadius, style: .continuous)
            .stroke(
                ReadyTypeTheme.warning.opacity(errorPulse ? 0.54 : 0.16),
                lineWidth: errorPulse ? 2.2 : 1.1
            )
            .shadow(
                color: ReadyTypeTheme.warning.opacity(errorPulse ? 0.24 : 0.08),
                radius: errorPulse ? 16 : 8,
                x: 0,
                y: 0
            )
            .animation(.easeOut(duration: 0.24).repeatCount(2, autoreverses: true), value: errorPulse)
    }

    private func horizontalSweep(in size: CGSize) -> some View {
        let tint = ReadyTypeTheme.color(for: role)
        let opacity = MotionTokens.voiceCapsuleFlowOpacity(for: state, preferences: preferences)
        let sweepWidth = max(size.width * 0.30, 120)
        let startX = -sweepWidth * 1.15
        let endX = size.width + sweepWidth * 0.65

        return Capsule()
            .fill(
                LinearGradient(
                    colors: [
                        .clear,
                        tint.opacity(opacity * 0.12),
                        ReadyTypeTheme.ink.opacity(opacity * 0.34),
                        tint.opacity(opacity),
                        ReadyTypeTheme.info.opacity(opacity * 0.45),
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: sweepWidth, height: 2.4)
            .blur(radius: 1.2)
            .offset(x: sweepPhase ? endX : startX)
            .shadow(
                color: tint.opacity(MotionTokens.voiceCapsuleGlowOpacity(for: state, preferences: preferences)),
                radius: 15,
                x: 0,
                y: 0
            )
            .animation(
                .linear(duration: MotionTokens.voiceCapsuleFlowDuration(for: state))
                .repeatForever(autoreverses: false),
                value: sweepPhase
            )
    }

    private func restartMotion() {
        guard !preferences.reduceMotion else {
            sweepPhase = false
            errorPulse = false
            return
        }

        sweepPhase = false
        errorPulse = false

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(24))
            sweepPhase = true
            if MotionTokens.voiceCapsuleErrorPulseEnabled(for: state, preferences: preferences) {
                errorPulse = true
            }
        }
    }
}

private struct VoiceCapsuleStatusLight: View {
    let role: StatusRole

    @State private var pulse = false
    private var preferences: MotionPreferences { .current }

    var body: some View {
        ZStack {
            Circle()
                .fill(ReadyTypeTheme.color(for: role).opacity(role == .neutral ? 0.10 : 0.20))
                .frame(width: 28, height: 28)
                .scaleEffect(role == .recording && !preferences.reduceMotion && pulse ? 1.12 : 1)

            Circle()
                .stroke(ReadyTypeTheme.color(for: role).opacity(0.26), lineWidth: 1)
                .frame(width: 22, height: 22)

            Circle()
                .fill(ReadyTypeTheme.color(for: role))
                .frame(width: 8, height: 8)
                .shadow(color: ReadyTypeTheme.color(for: role).opacity(role == .neutral ? 0 : 0.70), radius: 7, x: 0, y: 0)
                .scaleEffect(role == .recording && !preferences.reduceMotion && pulse ? 1.34 : 1)
        }
        .animation(
            role == .recording && !preferences.reduceMotion
            ? .easeInOut(duration: 0.92).repeatForever(autoreverses: true)
            : .default,
            value: pulse
        )
        .onAppear { pulse = true }
    }
}

private struct VoiceCapsuleBadge: View {
    let text: String
    let role: StatusRole

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(ReadyTypeTheme.field.opacity(0.82), in: Capsule())
            .foregroundStyle(role == .neutral ? ReadyTypeTheme.muted : ReadyTypeTheme.color(for: role))
            .overlay(
                Capsule()
                    .stroke(ReadyTypeTheme.color(for: role).opacity(role == .neutral ? 0.18 : 0.30), lineWidth: 1)
            )
    }
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
                        .fill(
                            LinearGradient(
                                colors: [
                                    ReadyTypeTheme.info.opacity(0.82),
                                    ReadyTypeTheme.accentStrong,
                                    ReadyTypeTheme.accent.opacity(0.72)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
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
        return 4 + clampedLevel * 16 * heightProfile[index]
    }
}
