import AppKit
import SwiftUI

enum FloatingAlertLayout {
    static let width: CGFloat = 360
    static let cornerRadius: CGFloat = 18
    static let inset: CGFloat = 18

    static func headline(unreadCount: Int?) -> String {
        guard let unreadCount, unreadCount > 0 else { return "Unread messages" }
        return unreadCount == 1 ? "1 unread message" : "\(unreadCount.formatted()) unread messages"
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

    private let surface = Color(nsColor: .controlBackgroundColor)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    Group {
                        if let icon { Image(nsImage: icon).resizable().interpolation(.high) }
                        else { Image(systemName: "app.fill").resizable().foregroundStyle(.secondary) }
                    }
                    .frame(width: 32, height: 32)
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(appName).font(.system(size: 13, weight: .semibold))
                        Text(isPreview ? "BadgeBell preview" : "BadgeBell")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Text(detectedAt, format: .dateTime.hour().minute())
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                        .accessibilityLabel("Detected at \(detectedAt.formatted(date: .omitted, time: .shortened))")
                    Button(action: dismissAction) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Hide this reminder; unread activity remains in the menu bar")
                    .accessibilityLabel("Hide this reminder")
                    .keyboardShortcut(.cancelAction)
                }

                Text(FloatingAlertLayout.headline(unreadCount: unreadCount))
                    .font(.system(size: 21, weight: .semibold))
                    .tracking(-0.4)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(FloatingAlertLayout.inset)

            HStack(spacing: 12) {
                Button(action: snoozeAction) {
                    Label("Snooze 10 min", systemImage: "clock")
                        .font(.system(size: 12, weight: .medium))
                        .padding(.vertical, 5)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.primary)
                .help("Pause reminders for 10 minutes, then check U again")

                Spacer(minLength: 8)
                Button("Open \(appName)", action: openAction)
                    .font(.system(size: 12, weight: .semibold))
                    .buttonStyle(.borderedProminent)
                    .tint(Color(nsColor: .systemBlue))
                    .controlSize(.large)
            }
            .padding(.horizontal, FloatingAlertLayout.inset)
            .padding(.vertical, 12)
            .background(Color.primary.opacity(0.035))
        }
        .environment(\.controlActiveState, .active)
        .frame(width: FloatingAlertLayout.width, alignment: .leading)
        .background(surface)
        .clipShape(RoundedRectangle(cornerRadius: FloatingAlertLayout.cornerRadius, style: .continuous))
    }
}
