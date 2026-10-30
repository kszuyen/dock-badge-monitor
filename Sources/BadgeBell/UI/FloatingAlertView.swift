import AppKit
import SwiftUI

enum FloatingAlertLayout {
    static let width: CGFloat = 330
    static let cornerRadius: CGFloat = 16
    static let inset: CGFloat = 14

    static func headline(unreadCount: Int?) -> String {
        guard let unreadCount, unreadCount > 0 else { return "Unread messages" }
        return unreadCount == 1 ? "1 unread message" : "\(unreadCount.formatted()) unread messages"
    }
}

/// Uses macOS's compositor to blur content behind the panel, rather than fading the text.
private struct ReminderMaterial: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

private struct ReminderButtonStyle: ButtonStyle {
    enum Role { case primary, secondary, close }
    let role: Role
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(role == .primary ? Color.white : Color.primary)
            .padding(.horizontal, role == .close ? 6 : 10)
            .padding(.vertical, 6)
            .background(background(pressed: configuration.isPressed), in: RoundedRectangle(cornerRadius: 8))
            .brightness(role == .primary && hovered ? 0.06 : 0)
            .scaleEffect(!reduceMotion && configuration.isPressed ? 0.96 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .onHover { hovered = $0 }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: hovered)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.1), value: configuration.isPressed)
    }

    private func background(pressed: Bool) -> Color {
        if role == .primary { return Color(nsColor: .systemBlue).opacity(pressed ? 0.8 : 1) }
        return Color.primary.opacity(pressed ? 0.14 : hovered ? 0.08 : 0)
    }
}

struct FloatingAlertView: View {
    let appName: String
    let unreadCount: Int?
    let icon: NSImage?
    let detectedAt: Date
    let isPreview: Bool
    let openAction: () -> Void
    let dismissAction: () -> Void
    let snoozeAction: () -> Void
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Group {
                    if let icon { Image(nsImage: icon).resizable().interpolation(.high) }
                    else { Image(systemName: "app.fill").resizable().foregroundStyle(.secondary) }
                }
                .frame(width: 30, height: 30)
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(isPreview ? "\(appName) · BadgeBell preview" : "\(appName) · BadgeBell")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    headline
                        .font(.system(size: 15, weight: .semibold))
                        .fixedSize(horizontal: false, vertical: true)
                        .help("Detected at \(detectedAt.formatted(date: .omitted, time: .shortened))")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button(action: dismissAction) {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .medium))
                }
                .buttonStyle(ReminderButtonStyle(role: .close))
                .help("Hide this reminder; unread activity remains in the menu bar")
                .accessibilityLabel("Hide this reminder")
                .keyboardShortcut(.cancelAction)
            }
            HStack(spacing: 8) {
                Spacer(minLength: 0)
                Button(action: snoozeAction) {
                    Label("Snooze 10 min", systemImage: "clock")
                }
                .buttonStyle(ReminderButtonStyle(role: .secondary))
                .help("Pause reminders for 10 minutes, then check U again")
                Button("Open \(appName)", action: openAction)
                    .buttonStyle(ReminderButtonStyle(role: .primary))
            }
        }
        .padding(FloatingAlertLayout.inset)
        .frame(width: FloatingAlertLayout.width, alignment: .leading)
        .background {
            if reduceTransparency { Color(nsColor: .controlBackgroundColor) }
            else { ReminderMaterial() }
        }
        .clipShape(RoundedRectangle(cornerRadius: FloatingAlertLayout.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FloatingAlertLayout.cornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.09), lineWidth: 0.5)
        }
        .environment(\.controlActiveState, .active)
    }

    @ViewBuilder
    private var headline: some View {
        if #available(macOS 14, *), !reduceMotion {
            Text(FloatingAlertLayout.headline(unreadCount: unreadCount))
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.18), value: unreadCount)
        } else {
            Text(FloatingAlertLayout.headline(unreadCount: unreadCount))
        }
    }
}
