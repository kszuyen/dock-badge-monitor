import XCTest
@testable import BadgeBell

final class AppMonitorProviderTests: XCTestCase {
    func testUnreadStateEquatable() {
        XCTAssertEqual(UnreadState.none, .none)
        XCTAssertEqual(UnreadState.hasUnread(count: nil), .hasUnread(count: nil))
        XCTAssertEqual(UnreadState.hasUnread(count: 3), .hasUnread(count: 3))
        XCTAssertNotEqual(UnreadState.none, .hasUnread(count: nil))
        XCTAssertNotEqual(UnreadState.hasUnread(count: nil), .hasUnread(count: 3))
        XCTAssertFalse(UnreadState.none.hasUnread)
        XCTAssertTrue(UnreadState.hasUnread(count: nil).hasUnread)
        XCTAssertTrue(UnreadState.hasUnread(count: 3).hasUnread)
    }

    func testProviderSnapshotStoresState() {
        let snapshot = AppMonitorSnapshot(
            providerID: "cyberlink-u",
            appName: "U",
            isInstalled: true,
            isRunning: false,
            unreadState: .hasUnread(count: 2)
        )

        XCTAssertEqual(snapshot.providerID, "cyberlink-u")
        XCTAssertEqual(snapshot.appName, "U")
        XCTAssertTrue(snapshot.isInstalled)
        XCTAssertFalse(snapshot.isRunning)
        XCTAssertEqual(snapshot.unreadState, .hasUnread(count: 2))
    }
}
