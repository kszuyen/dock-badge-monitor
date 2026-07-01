import XCTest
@testable import BadgeBell

final class CyberLinkUProviderTests: XCTestCase {
    func testMetadata() {
        let provider = CyberLinkUProvider(
            appLocator: StubAppLocator(),
            badgeReader: StubBadgeReader(),
            appOpener: StubAppOpener()
        )

        XCTAssertEqual(provider.id, "cyberlink-u")
        XCTAssertEqual(provider.appName, "U")
        XCTAssertEqual(provider.bundleIdentifier, "com.cyberlink.u")
    }

    func testSnapshotUsesInjectedDependencies() {
        let provider = CyberLinkUProvider(
            appLocator: StubAppLocator(isInstalled: true, isRunning: true),
            badgeReader: StubBadgeReader(unreadState: .hasUnread(count: 7)),
            appOpener: StubAppOpener()
        )

        let snapshot = provider.snapshot()

        XCTAssertEqual(snapshot.providerID, "cyberlink-u")
        XCTAssertEqual(snapshot.appName, "U")
        XCTAssertTrue(snapshot.isInstalled)
        XCTAssertTrue(snapshot.isRunning)
        XCTAssertEqual(snapshot.unreadState, .hasUnread(count: 7))
    }

    func testOpenAppUsesCyberLinkUBundleIdentifier() {
        let opener = StubAppOpener()
        let provider = CyberLinkUProvider(
            appLocator: StubAppLocator(),
            badgeReader: StubBadgeReader(),
            appOpener: opener
        )

        provider.openApp()

        XCTAssertEqual(opener.openedBundleIdentifiers, ["com.cyberlink.u"])
    }
}

private final class StubAppLocator: AppLocating, @unchecked Sendable {
    private let isInstalled: Bool
    private let isRunning: Bool

    init(isInstalled: Bool = false, isRunning: Bool = false) {
        self.isInstalled = isInstalled
        self.isRunning = isRunning
    }

    func appIsInstalled(bundleIdentifier: String) -> Bool {
        isInstalled
    }

    func appIsRunning(bundleIdentifier: String) -> Bool {
        isRunning
    }
}

private final class StubBadgeReader: BadgeReading, @unchecked Sendable {
    private let unreadState: UnreadState

    init(unreadState: UnreadState = .none) {
        self.unreadState = unreadState
    }

    func unreadState(bundleIdentifier: String) -> UnreadState {
        unreadState
    }
}

private final class StubAppOpener: AppOpening, @unchecked Sendable {
    private(set) var openedBundleIdentifiers: [String] = []

    func open(bundleIdentifier: String) {
        openedBundleIdentifiers.append(bundleIdentifier)
    }
}
