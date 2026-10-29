import XCTest
@testable import BadgeBell

final class FloatingAlertLayoutTests: XCTestCase {
    func testHeadlinesUseRealCountsAndDoNotGuessMissingValues() {
        XCTAssertEqual(FloatingAlertLayout.headline(unreadCount: 1), "1 unread message")
        XCTAssertEqual(FloatingAlertLayout.headline(unreadCount: 3), "3 unread messages")
        XCTAssertEqual(FloatingAlertLayout.headline(unreadCount: nil), "Unread messages")
        XCTAssertEqual(FloatingAlertLayout.headline(unreadCount: 0), "Unread messages")
    }
}
