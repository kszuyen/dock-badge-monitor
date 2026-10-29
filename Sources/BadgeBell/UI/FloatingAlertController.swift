import AppKit
import SwiftUI

private final class ReminderPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class FloatingAlertController {
    private var window: NSPanel?
    private var hostingView: NSHostingView<FloatingAlertView>?
    private var lastPresentation: Presentation?
    private let openAction: () -> Void
    private let dismissAction: () -> Void
    private let snoozeAction: () -> Void

    private struct Presentation: Equatable {
        let snapshot: AppMonitorSnapshot
        let date: Date
        let isPreview: Bool
        let screenMode: String
        let fullScreen: Bool
    }

    init(openAction: @escaping () -> Void, dismissAction: @escaping () -> Void = {}, snoozeAction: @escaping () -> Void = {}) {
        self.openAction = openAction
        self.dismissAction = dismissAction
        self.snoozeAction = snoozeAction
    }

    func show(snapshot: AppMonitorSnapshot, detectedAt: Date = Date(), isPreview: Bool = false,
              screenMode: String = "active", showInFullScreen: Bool = true) {
        let presentation = Presentation(snapshot: snapshot, date: detectedAt, isPreview: isPreview,
                                        screenMode: screenMode, fullScreen: showInFullScreen)
        guard presentation != lastPresentation || window?.isVisible != true else { return }
        let wasVisible = window?.isVisible == true
        let oldPresentation = lastPresentation
        lastPresentation = presentation
        let icon = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.cyberlink.u")
            .map { NSWorkspace.shared.icon(forFile: $0.path) }
        let count: Int?
        if case .hasUnread(let value) = snapshot.unreadState { count = value } else { count = nil }
        let view = FloatingAlertView(appName: snapshot.appName, unreadCount: count, icon: icon,
                                     detectedAt: detectedAt, isPreview: isPreview,
                                     openAction: openAction, dismissAction: dismissAction, snoozeAction: snoozeAction)
        if window == nil {
            let panel = ReminderPanel(contentRect: NSRect(x: 0, y: 0, width: FloatingAlertLayout.width, height: 140),
                                      styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.level = .floating
            panel.hidesOnDeactivate = false
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.isReleasedWhenClosed = false
            panel.hasShadow = true
            panel.isMovableByWindowBackground = false
            window = panel
        }
        guard let window else { return }
        window.collectionBehavior = showInFullScreen ? [.canJoinAllSpaces, .fullScreenAuxiliary] : [.canJoinAllSpaces]
        if let hostingView { hostingView.rootView = view }
        else {
            let host = NSHostingView(rootView: view)
            host.sizingOptions = [.intrinsicContentSize]
            hostingView = host
            window.contentView = host
        }
        hostingView?.layoutSubtreeIfNeeded()
        let size = hostingView?.fittingSize ?? NSSize(width: FloatingAlertLayout.width, height: 150)
        let screen: NSScreen?
        if wasVisible && oldPresentation?.screenMode == screenMode && oldPresentation?.fullScreen == showInFullScreen {
            screen = window.screen
        } else if screenMode == "main" { screen = NSScreen.screens.first }
        else { screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) }
        let frame = (screen ?? NSScreen.main ?? NSScreen.screens.first)?.visibleFrame ?? .zero
        let width = min(FloatingAlertLayout.width, frame.width - 40)
        let rect = NSRect(x: frame.maxX - width - 20, y: frame.maxY - size.height - 20,
                          width: width, height: max(100, size.height))
        if window.frame != rect { window.setFrame(rect, display: true) }
        // A nonactivating panel keeps keyboard focus in the user's current application.
        window.orderFrontRegardless()
        window.invalidateShadow()
    }

    func invalidatePlacement() { lastPresentation = nil }

    func dismiss() {
        if window?.isVisible == true { window?.orderOut(nil) }
        lastPresentation = nil
    }
}
