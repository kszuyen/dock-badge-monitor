import AppKit
import SwiftUI

@MainActor
final class FloatingAlertController {
    private var window: NSWindow?
    private let openAction: @MainActor () -> Void

    init(openAction: @escaping @MainActor () -> Void) {
        self.openAction = openAction
    }

    func show(snapshot: AppMonitorSnapshot) {
        let view = FloatingAlertView(
            title: "\(snapshot.appName) has unread messages",
            subtitle: "BadgeBell",
            openAction: { [weak self] in
                self?.openAction()
                self?.dismiss()
            },
            dismissAction: { [weak self] in
                self?.dismiss()
            }
        )

        let hostingView = NSHostingView(rootView: view)
        let alertWindow = window ?? makeWindow()
        alertWindow.contentView = hostingView
        window = alertWindow

        positionTopRight()
        alertWindow.orderFrontRegardless()
    }

    func dismiss() {
        window?.orderOut(nil)
    }

    private func makeWindow() -> NSWindow {
        let alertWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: FloatingAlertLayout.width, height: 1),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        alertWindow.level = .floating
        alertWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        alertWindow.backgroundColor = .clear
        alertWindow.isOpaque = false
        alertWindow.isReleasedWhenClosed = false
        alertWindow.hasShadow = false
        return alertWindow
    }

    private func positionTopRight() {
        guard let window else {
            return
        }

        let visibleFrame = NSScreen.main?.visibleFrame ?? NSScreen.screens.first?.visibleFrame ?? .zero
        let fittingSize = window.contentView?.fittingSize ?? NSSize(width: FloatingAlertLayout.width, height: 1)
        let size = NSSize(width: FloatingAlertLayout.width, height: fittingSize.height)
        let margin: CGFloat = 20
        let origin = NSPoint(
            x: visibleFrame.maxX - size.width - margin,
            y: visibleFrame.maxY - size.height - margin
        )

        window.setFrame(NSRect(origin: origin, size: size), display: true)
    }
}
