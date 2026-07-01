import SwiftUI

enum FloatingAlertLayout {
    static let width: CGFloat = 340
    static let cornerRadius: CGFloat = 16
}

struct FloatingAlertView: View {
    let title: String
    let subtitle: String
    let openAction: () -> Void
    let dismissAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                appBadge

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold, design: .default))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular, design: .default))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: dismissAction) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .background(.quaternary.opacity(0.8), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss")
            }

            HStack(spacing: 10) {
                Button(action: dismissAction) {
                    Text("Dismiss")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)

                Button(action: openAction) {
                    Label("Open U", systemImage: "arrow.up.forward.app")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
        }
        .padding(16)
        .frame(width: FloatingAlertLayout.width, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: FloatingAlertLayout.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FloatingAlertLayout.cornerRadius, style: .continuous)
                .stroke(.white.opacity(0.55), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.18), radius: 24, x: 0, y: 14)
        .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 1)
    }

    private var appBadge: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(.blue.opacity(0.14))
                .overlay {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(.blue.opacity(0.18), lineWidth: 1)
                }
                .frame(width: 38, height: 38)

            Text("U")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.blue)
                .frame(width: 38, height: 38)

            Circle()
                .fill(.red)
                .frame(width: 10, height: 10)
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.9), lineWidth: 1.5)
                }
                .offset(x: 1, y: -1)
        }
        .accessibilityHidden(true)
    }
}
