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
        let prefix = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "badgebell-reminder"
        let previewCount: Int? = CommandLine.arguments.count > 3 ? Int(CommandLine.arguments[3]) : 3
        let icon = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.cyberlink.u")
            .map { NSWorkspace.shared.icon(forFile: $0.path) }
        for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", NSAppearance.Name.darkAqua)] {
            let panel = NSPanel(contentRect: NSRect(x: -10000, y: -10000, width: FloatingAlertLayout.width, height: 180),
                                styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.appearance = NSAppearance(named: appearance)
            panel.backgroundColor = .windowBackgroundColor
            let view = FloatingAlertView(appName: "U", unreadCount: previewCount, icon: icon, detectedAt: Date(), isPreview: true,
                                         openAction: {}, dismissAction: {}, snoozeAction: {})
            let host = NSHostingView(rootView: view)
            host.sizingOptions = [.intrinsicContentSize]
            panel.contentView = host
            host.layoutSubtreeIfNeeded()
            let fitting = host.fittingSize
            print("Rendering \(name): \(fitting)")
            panel.setContentSize(NSSize(width: FloatingAlertLayout.width, height: fitting.height))
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
            try png.write(to: directory.appendingPathComponent("\(prefix)-\(name).png"))
            panel.orderOut(nil)

            let header = MenuStatusHeaderView()
            header.update(title: previewCount.map { "U · \($0.formatted()) unread" } ?? "U: Unread", detail: "Monitoring · every 10s")
            let headerPanel = NSPanel(contentRect: header.frame, styleMask: [.borderless], backing: .buffered, defer: false)
            headerPanel.appearance = NSAppearance(named: appearance)
            headerPanel.contentView = header
            header.wantsLayer = true
            headerPanel.appearance?.performAsCurrentDrawingAppearance {
                header.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
            }
            headerPanel.setFrameOrigin(NSPoint(x: -10000, y: -10000))
            headerPanel.orderFrontRegardless()
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
            header.layoutSubtreeIfNeeded()
            if let bitmap = header.bitmapImageRepForCachingDisplay(in: header.bounds) {
                header.cacheDisplay(in: header.bounds, to: bitmap)
                try bitmap.representation(using: .png, properties: [:])?.write(
                    to: directory.appendingPathComponent("\(prefix)-menu-header-\(name).png"))
            }
            headerPanel.orderOut(nil)
        }
    }
}
