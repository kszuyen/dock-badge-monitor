import XCTest
@testable import BadgeBell

final class DockBadgeReaderTests: XCTestCase {
    func testMissingDockIsReportedAsUnavailableInsteadOfHealthy() {
        let reader = DockBadgeReader(targetAppName: "U", snapshotProvider: StubDockItemSnapshotProvider(snapshots: []))
        XCTAssertEqual(reader.readStatus(bundleIdentifier: "com.cyberlink.u").issue, .dockUnavailable)
    }

    func testMissingTargetIsDistinctFromAnEmptyBadge() {
        let reader = DockBadgeReader(targetAppName: "U", snapshotProvider: StubDockItemSnapshotProvider(snapshots: [
            DockItemSnapshot(identifier: "finder", title: "Finder", description: "", statusLabel: "", accessibleDescription: "")
        ]))
        XCTAssertEqual(reader.readStatus(bundleIdentifier: "com.cyberlink.u").issue, .badgeUnavailable)
        let emptyBadge = DockBadgeReader(targetAppName: "U", snapshotProvider: StubDockItemSnapshotProvider(snapshots: [
            DockItemSnapshot(identifier: "com.cyberlink.u", title: "U", description: "", statusLabel: "", accessibleDescription: "")
        ]))
        XCTAssertNil(emptyBadge.readStatus(bundleIdentifier: "com.cyberlink.u").issue)
        XCTAssertEqual(emptyBadge.unreadState(bundleIdentifier: "com.cyberlink.u"), .none)
    }

    func testUnreadStateReadsMatchingSnapshotByBundleIdentifier() {
        let provider = StubDockItemSnapshotProvider(snapshots: [
            DockItemSnapshot(identifier: "com.apple.finder", title: "Finder", description: "", statusLabel: "", accessibleDescription: ""),
            DockItemSnapshot(identifier: "com.cyberlink.u", title: "U", description: "", statusLabel: "2 notifications", accessibleDescription: "")
        ])
        let reader = DockBadgeReader(targetAppName: "U", snapshotProvider: provider)

        XCTAssertEqual(reader.unreadState(bundleIdentifier: "com.cyberlink.u"), .hasUnread(count: 2))
    }

    func testUnreadStateMatchesExactTargetAppName() {
        let provider = StubDockItemSnapshotProvider(snapshots: [
            DockItemSnapshot(identifier: "", title: "U", description: "", statusLabel: "1 new item", accessibleDescription: "")
        ])
        let reader = DockBadgeReader(targetAppName: "U", snapshotProvider: provider)

        XCTAssertEqual(reader.unreadState(bundleIdentifier: "com.cyberlink.u"), .hasUnread(count: 1))
    }

    func testUnreadStateDoesNotUseSingleCharacterAppNameAsBroadSubstring() {
        let provider = StubDockItemSnapshotProvider(snapshots: [
            DockItemSnapshot(identifier: "com.apple.launchpad", title: "Launchpad", description: "", statusLabel: "3 notifications", accessibleDescription: "")
        ])
        let reader = DockBadgeReader(targetAppName: "U", snapshotProvider: provider)

        XCTAssertEqual(reader.unreadState(bundleIdentifier: "com.cyberlink.u"), .none)
    }
}

private struct StubDockItemSnapshotProvider: DockItemSnapshotProviding {
    let snapshots: [DockItemSnapshot]

    func dockItemSnapshots() -> [DockItemSnapshot] {
        snapshots
    }
}
