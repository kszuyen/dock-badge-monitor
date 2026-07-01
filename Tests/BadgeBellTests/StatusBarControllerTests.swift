import XCTest
@testable import BadgeBell

@MainActor
final class StatusBarControllerTests: XCTestCase {
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
