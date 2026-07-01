import AppKit

public enum BadgeBellApplication {
    @MainActor
    private static let delegate = AppDelegate()

    @MainActor
    public static func run() {
        let application = NSApplication.shared

        application.setActivationPolicy(.accessory)
        application.delegate = delegate
        application.run()
    }
}
