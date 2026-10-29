import AppKit
import XCTest
@testable import BadgeBell

@MainActor
final class StatusBarControllerTests: XCTestCase {
    func testQuicklyReopenedMenuRemainsFrozenUntilItsOwnClose() async {
        let controller = StatusBarController(openU: {}, dismissAlert: {}, quit: {})
        let menu = NSMenu()
        controller.menuWillOpen(menu)
        controller.setAccessibilityPermissionRequired()
        controller.menuDidClose(menu)
        controller.menuWillOpen(menu)
        let oldClose = expectation(description: "Old close callback executed")
        DispatchQueue.main.async { oldClose.fulfill() }
        await fulfillment(of: [oldClose], timeout: 2)
        XCTAssertEqual(controller.statusTitleForTesting, "U: Checking")
        controller.menuDidClose(menu)
        let newClose = expectation(description: "New close callback executed")
        DispatchQueue.main.async { newClose.fulfill() }
        await fulfillment(of: [newClose], timeout: 2)
        XCTAssertEqual(controller.statusTitleForTesting, "U: Accessibility permission needed")
    }

    func testPollingCannotRelayoutOpenMenuAndLatestStatusIsAppliedAfterClose() async {
        let controller = StatusBarController(openU: {}, dismissAlert: {}, quit: {})
        let menu = NSMenu()
        controller.menuWillOpen(menu)
        for index in 0..<300 {
            controller.updateSnapshot(AppMonitorSnapshot(
                providerID: "cyberlink-u", appName: "U", isInstalled: true,
                isRunning: true, unreadState: index.isMultiple(of: 2) ? .none : .hasUnread(count: index)
            ))
            controller.setAlertActive(true)
        }
        XCTAssertEqual(controller.statusTitleForTesting, "U: Checking")
        controller.menuDidClose(menu)
        XCTAssertEqual(controller.statusTitleForTesting, "U: Checking")
        let applied = expectation(description: "Menu event loop finished")
        DispatchQueue.main.async { applied.fulfill() }
        await fulfillment(of: [applied], timeout: 2)
        XCTAssertEqual(controller.statusTitleForTesting, "U: Unread")
    }

    func testPausedStatusStillReportsMissingPermission() {
        let controller = StatusBarController(openU: {}, dismissAlert: {}, quit: {}, alertsPaused: true)
        controller.updateSnapshot(AppMonitorSnapshot(
            providerID: "cyberlink-u", appName: "U", isInstalled: true,
            isRunning: true, unreadState: .none
        ))
        XCTAssertEqual(controller.statusTitleForTesting, "U: Monitoring (alerts paused)")
        controller.setAccessibilityPermissionRequired()
        XCTAssertEqual(controller.statusTitleForTesting, "U: Accessibility permission needed")
    }

    func testShowsAccessibilityPermissionStatus() {
        let controller = StatusBarController(openU: {}, dismissAlert: {}, quit: {})

        controller.setAccessibilityPermissionRequired()

        XCTAssertEqual(controller.statusTitleForTesting, "U: Accessibility permission needed")
    }

    func testShowsSelectedPollingInterval() {
        let controller = StatusBarController(
            openU: {},
            dismissAlert: {},
            quit: {},
            pollingInterval: 2.0,
            setPollingInterval: { _ in }
        )

        XCTAssertEqual(
            controller.pollingIntervalStatesForTesting,
            [
                "Check every 1s": false,
                "Check every 2s": true,
                "Check every 5s": false,
                "Check every 10s": false,
            ]
        )
    }

    func testSelectingPollingIntervalNotifiesConsumerAndUpdatesSelection() {
        var selectedIntervals: [Double] = []
        let controller = StatusBarController(
            openU: {},
            dismissAlert: {},
            quit: {},
            pollingInterval: 2.0,
            setPollingInterval: { selectedIntervals.append($0) }
        )

        controller.selectPollingIntervalForTesting(5.0)

        XCTAssertEqual(selectedIntervals, [5.0])
        XCTAssertEqual(controller.pollingIntervalStatesForTesting["Check every 5s"], true)
        XCTAssertEqual(controller.pollingIntervalStatesForTesting["Check every 2s"], false)
    }

    func testShowsAlertsPausedState() {
        let controller = StatusBarController(
            openU: {},
            dismissAlert: {},
            quit: {},
            alertsPaused: true,
            setAlertsPaused: { _ in }
        )

        XCTAssertEqual(controller.alertsPausedTitleForTesting, "Resume Alerts")
    }

    func testTogglingAlertsPausedNotifiesConsumerAndUpdatesTitle() {
        var selectedStates: [Bool] = []
        let controller = StatusBarController(
            openU: {},
            dismissAlert: {},
            quit: {},
            alertsPaused: false,
            setAlertsPaused: { selectedStates.append($0) }
        )

        controller.toggleAlertsPausedForTesting()

        XCTAssertEqual(selectedStates, [true])
        XCTAssertEqual(controller.alertsPausedTitleForTesting, "Resume Alerts")
    }
}
