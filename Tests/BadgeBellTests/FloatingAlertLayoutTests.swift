import XCTest
@testable import BadgeBell

final class FloatingAlertLayoutTests: XCTestCase {
    func testNativeGlassLayoutMetrics() {
        XCTAssertEqual(FloatingAlertLayout.width, 350)
        XCTAssertEqual(FloatingAlertLayout.cornerRadius, 16)
    }
}
