import AppKit
import SwiftUI

enum FloatingAlertLayout {
    static let width: CGFloat = 350
    static let cornerRadius: CGFloat = 16
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

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Group {
                    if let icon { Image(nsImage: icon).resizable().interpolation(.high) }
                    else { Image(systemName: "app.fill").resizable().foregroundStyle(.secondary) }
                }
                .frame(width: 38, height: 38)
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text(isPreview ? "BadgeBell · Preview" : "BadgeBell · \(appName)")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                    Text("You have unread messages")
                        .font(.system(size: 14, weight: .semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(unreadCount.map { "\($0) unread · Detected at \(detectedAt.formatted(date: .omitted, time: .shortened))" }
                         ?? "Unread activity detected")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button(action: dismissAction) {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary).frame(width: 24, height: 24).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Hide this reminder; unread activity remains in the menu bar")
                .accessibilityLabel("Hide this reminder")
                .keyboardShortcut(.cancelAction)
            }
            HStack(spacing: 8) {
                Spacer(minLength: 0)
                Button("Remind in 10 min", action: snoozeAction)
                    .buttonStyle(.bordered)
                    .help("Pause reminders for 10 minutes, then check U again")
                Button("Open \(appName)", action: openAction)
                    .buttonStyle(.borderedProminent)
            }
            .controlSize(.regular)
        }
        .environment(\.controlActiveState, .active)
        .padding(16)
        .frame(width: FloatingAlertLayout.width, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: FloatingAlertLayout.cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: FloatingAlertLayout.cornerRadius)
                .strokeBorder(.primary.opacity(0.09), lineWidth: 0.5)
        }
    }
}
