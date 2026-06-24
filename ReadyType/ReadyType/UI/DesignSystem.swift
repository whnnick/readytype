import SwiftUI

enum ReadyTypeTheme {
    static let canvas = Color(red: 0.055, green: 0.064, blue: 0.059)
    static let sidebar = Color(red: 0.043, green: 0.050, blue: 0.047)
    static let field = Color(red: 0.102, green: 0.118, blue: 0.108).opacity(0.96)
    static let fieldStrong = Color(red: 0.133, green: 0.153, blue: 0.141)
    static let stroke = Color(red: 0.251, green: 0.290, blue: 0.263)
    static let strokeSoft = Color(red: 0.184, green: 0.216, blue: 0.196)
    static let ink = Color(red: 0.930, green: 0.948, blue: 0.921)
    static let muted = Color(red: 0.646, green: 0.696, blue: 0.652)
    static let accent = Color(red: 0.510, green: 0.745, blue: 0.547)
    static let accentStrong = Color(red: 0.565, green: 0.824, blue: 0.604)
    static let accentSoft = Color(red: 0.157, green: 0.235, blue: 0.169)
    static let panelStroke = stroke.opacity(0.88)
    static let pageBackground = canvas
    static let warning = Color(red: 0.950, green: 0.645, blue: 0.265)
    static let danger = Color(red: 0.950, green: 0.376, blue: 0.329)
    static let info = Color(red: 0.439, green: 0.663, blue: 0.855)

    static func color(for role: StatusRole) -> Color {
        switch role {
        case .neutral:
            return muted
        case .recording:
            return accentStrong
        case .progress:
            return info
        case .success:
            return accent
        case .warning:
            return warning
        case .danger:
            return danger
        }
    }
}

struct ReadyTypePanel<Content: View>: View {
    private let title: String
    private let subtitle: String?
    private let content: Content

    init(_ title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(ReadyTypeTheme.ink)
                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(ReadyTypeTheme.muted)
                }
            }

            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ReadyTypeTheme.field, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(ReadyTypeTheme.panelStroke, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.32), radius: 18, x: 0, y: 12)
    }
}

struct StatusDot: View {
    let role: StatusRole
    var size: CGFloat = 9

    @State private var breath = false
    private var preferences: MotionPreferences { .current }

    var body: some View {
        Circle()
            .fill(ReadyTypeTheme.color(for: role))
            .frame(width: size, height: size)
            .scaleEffect(role == .recording && !preferences.reduceMotion && breath ? 1.45 : 1)
            .opacity(role == .recording && !preferences.reduceMotion && breath ? 0.58 : 1)
            .animation(
                role == .recording && !preferences.reduceMotion
                ? .easeInOut(duration: 0.82).repeatForever(autoreverses: true)
                : .default,
                value: breath
            )
            .onAppear { breath = true }
    }
}

struct ModeBadge: View {
    let mode: OutputMode

    var body: some View {
        Text(mode.displayName)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(ReadyTypeTheme.accentSoft, in: Capsule())
            .foregroundStyle(ReadyTypeTheme.accentStrong)
            .overlay(
                Capsule()
                    .stroke(ReadyTypeTheme.strokeSoft, lineWidth: 1)
            )
    }
}

struct RecognitionModeBadge: View {
    let mode: SpeechRecognitionMode

    var body: some View {
        Text(mode.displayName)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(ReadyTypeTheme.fieldStrong, in: Capsule())
            .foregroundStyle(ReadyTypeTheme.info)
            .overlay(
                Capsule()
                    .stroke(ReadyTypeTheme.info.opacity(0.24), lineWidth: 1)
            )
    }
}

struct StatusPill: View {
    let state: RuntimeState
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            StatusDot(role: state.readyTypeStatusRole)
            Text(message)
                .font(.callout.weight(.medium))
                .lineLimit(1)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(ReadyTypeTheme.fieldStrong, in: Capsule())
        .overlay(
            Capsule()
                .stroke(ReadyTypeTheme.color(for: state.readyTypeStatusRole).opacity(0.24), lineWidth: 1)
        )
        .foregroundStyle(ReadyTypeTheme.color(for: state.readyTypeStatusRole))
    }
}

struct EmptyPreviewText: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(ReadyTypeTheme.muted)
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            .padding(12)
            .background(ReadyTypeTheme.fieldStrong.opacity(0.58), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(ReadyTypeTheme.panelStroke, lineWidth: 1)
            )
    }
}

struct ReadyTypeMark: View {
    var size: CGFloat = 42

    private let markBackground = Color(red: 0.965, green: 0.969, blue: 0.949)
    private let markStroke = Color(red: 0.850, green: 0.871, blue: 0.824)
    private let markField = Color.white
    private let markInk = Color(red: 0.094, green: 0.129, blue: 0.114)
    private let markMoss = Color(red: 0.369, green: 0.498, blue: 0.392)
    private let markSuccess = Color(red: 0.184, green: 0.561, blue: 0.357)

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(markBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                        .stroke(markStroke, lineWidth: max(1, size * 0.018))
                )

            RoundedRectangle(cornerRadius: size * 0.10, style: .continuous)
                .fill(markField)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.10, style: .continuous)
                        .stroke(markStroke, lineWidth: max(1, size * 0.016))
                )
                .frame(width: size * 0.64, height: size * 0.44)

            HStack(alignment: .center, spacing: size * 0.075) {
                Capsule()
                    .fill(markInk)
                    .frame(width: size * 0.045, height: size * 0.26)
                Capsule()
                    .fill(markMoss.opacity(0.88))
                    .frame(width: size * 0.045, height: size * 0.14)
                Capsule()
                    .fill(markMoss)
                    .frame(width: size * 0.045, height: size * 0.22)
                Capsule()
                    .fill(markMoss.opacity(0.88))
                    .frame(width: size * 0.045, height: size * 0.13)
            }
            .offset(x: -size * 0.05)

            Image(systemName: "checkmark")
                .font(.system(size: size * 0.25, weight: .bold))
                .foregroundStyle(markSuccess)
                .offset(x: size * 0.28, y: size * 0.04)
        }
        .frame(width: size, height: size)
    }
}
