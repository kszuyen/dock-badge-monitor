import Foundation

public struct CyberLinkUProvider: AppMonitorProvider {
    public let id = "cyberlink-u"
    public let appName = "U"
    public let bundleIdentifier = "com.cyberlink.u"

    private let appLocator: any AppLocating
    private let badgeReader: any BadgeReading
    private let appOpener: any AppOpening

    public init(
        appLocator: any AppLocating = WorkspaceAppLocator(),
        badgeReader: any BadgeReading = DockBadgeReader(targetAppName: "U"),
        appOpener: any AppOpening = WorkspaceAppOpener()
    ) {
        self.appLocator = appLocator
        self.badgeReader = badgeReader
        self.appOpener = appOpener
    }

    public func snapshot() -> AppMonitorSnapshot {
        AppMonitorSnapshot(
            providerID: id,
            appName: appName,
            isInstalled: appLocator.appIsInstalled(bundleIdentifier: bundleIdentifier),
            isRunning: appLocator.appIsRunning(bundleIdentifier: bundleIdentifier),
            unreadState: badgeReader.unreadState(bundleIdentifier: bundleIdentifier)
        )
    }

    public func openApp() {
        appOpener.open(bundleIdentifier: bundleIdentifier)
    }
}
