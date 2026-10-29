import AppKit
import SwiftUI

/// Renders the actual reminder view without capturing the user's screen.
@main
struct RenderUIPreview {
    @MainActor
    static func main() throws {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        let directory = URL(fileURLWithPath: CommandLine.arguments[1])
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let icon = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.cyberlink.u")
            .map { NSWorkspace.shared.icon(forFile: $0.path) }
        for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", NSAppearance.Name.darkAqua)] {
            let panel = NSPanel(contentRect: NSRect(x: -10000, y: -10000, width: 350, height: 180),
                                styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.appearance = NSAppearance(named: appearance)
            panel.backgroundColor = .windowBackgroundColor
            let view = FloatingAlertView(appName: "U", unreadCount: 3, icon: icon, detectedAt: Date(), isPreview: true,
                                         openAction: {}, dismissAction: {}, snoozeAction: {})
            let host = NSHostingView(rootView: view)
            host.sizingOptions = [.intrinsicContentSize]
            panel.contentView = host
            host.layoutSubtreeIfNeeded()
            let fitting = host.fittingSize
            print("Rendering \(name): \(fitting)")
            panel.setContentSize(NSSize(width: 350, height: max(140, fitting.height)))
            panel.orderFrontRegardless()
            RunLoop.main.run(until: Date().addingTimeInterval(0.25))
            host.layoutSubtreeIfNeeded()
            guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
                throw NSError(domain: "BadgeBellPreview", code: 1)
            }
            host.cacheDisplay(in: host.bounds, to: bitmap)
            guard let png = bitmap.representation(using: .png, properties: [:]) else {
                throw NSError(domain: "BadgeBellPreview", code: 2)
            }
            try png.write(to: directory.appendingPathComponent("badgebell-reminder-\(name).png"))
            panel.orderOut(nil)
        }
    }
}
