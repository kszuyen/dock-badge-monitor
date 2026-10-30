import AppKit
import XCTest
@testable import BadgeBell

@MainActor
final class StatusBarControllerTests: XCTestCase {
    private func drainMenuCallbacks() async {
        let applied = expectation(description: "Menu tracking callbacks finished")
        DispatchQueue.main.async { applied.fulfill() }
        await fulfillment(of: [applied], timeout: 2)
    }

    func testQuickReopenAndNestedMenusStayFrozenUntilAllMenusClose() async {
        let controller = StatusBarController()
        let submenu = NSMenu()
        controller.menuWillOpen(controller.menu)
        controller.update(reminder: ReminderState(), permissionRequired: true)
        controller.menuWillOpen(submenu)
        controller.menuDidClose(submenu)
        await drainMenuCallbacks()
        XCTAssertEqual(controller.statusTitleForTesting, "U: Checking")
        controller.menuDidClose(controller.menu)
        controller.menuWillOpen(controller.menu)
        await drainMenuCallbacks()
        XCTAssertEqual(controller.statusTitleForTesting, "U: Checking")
        controller.menuDidClose(controller.menu)
        XCTAssertEqual(controller.statusTitleForTesting, "U: Checking")
        await drainMenuCallbacks()
        XCTAssertEqual(controller.statusTitleForTesting, "U: Permission needed")
    }

    func testRepeatedPollingDoesNotChangeOpenMenuOrStatusIcon() async {
        let controller = StatusBarController()
        var reminder = ReminderState()
        controller.menuWillOpen(controller.menu)
        for index in 1...300 {
            reminder.receive(snapshot(.hasUnread(count: index)))
            controller.update(reminder: reminder)
        }
        XCTAssertEqual(controller.statusTitleForTesting, "U: Checking")
        XCTAssertEqual(controller.symbolForTesting, "bell")
        controller.menuDidClose(controller.menu)
        await drainMenuCallbacks()
        XCTAssertEqual(controller.statusTitleForTesting, "U · 300 unread")
        XCTAssertEqual(controller.symbolForTesting, "bell.badge")
    }

    func testPauseIsAnActionWithoutCheckmarkAndResumeHasNoSubmenu() {
        let controller = StatusBarController()
        XCTAssertNotNil(controller.pauseItemForTesting.submenu)
        XCTAssertEqual(controller.pauseItemForTesting.state, .off)
        var reminder = ReminderState()
        reminder.pause(minutes: 30)
        controller.update(reminder: reminder)
        XCTAssertEqual(controller.pauseItemForTesting.title, "Resume Alerts")
        XCTAssertNil(controller.pauseItemForTesting.submenu)
        XCTAssertEqual(controller.pauseItemForTesting.state, .off)
        XCTAssertTrue(controller.statusDetailForTesting.contains("30 min"))
        XCTAssertEqual(controller.symbolForTesting, "bell.slash")
    }

    func testHideKeepsUnreadIconAndDisablesHideAction() {
        let controller = StatusBarController()
        var reminder = ReminderState()
        reminder.receive(snapshot(.hasUnread(count: 2)))
        reminder.hide()
        controller.update(reminder: reminder)
        XCTAssertEqual(controller.symbolForTesting, "bell.badge")
        XCTAssertFalse(controller.hideItemForTesting.isEnabled)
        XCTAssertEqual(controller.statusTitleForTesting, "U · 2 unread")
    }

    func testNativeMenuDispatchesTimedPauseAndIntervalActions() throws {
        var chosenPause: Double?
        var chosenInterval: Double?
        var actions = StatusBarController.Actions()
        actions.pause = { chosenPause = $0 }
        actions.interval = { chosenInterval = $0 }
        let controller = StatusBarController(actions: actions)
        let pause = try XCTUnwrap(controller.pauseItemForTesting.submenu)
        pause.performActionForItem(at: 1)
        XCTAssertEqual(chosenPause, 30)
        let intervals = try XCTUnwrap(controller.intervalItemForTesting.submenu)
        intervals.performActionForItem(at: 2)
        XCTAssertEqual(chosenInterval, 5)
    }

    func testStatusSummaryKeepsItsFixedSizeForErrorsAndPreviewStaysInHelp() throws {
        let controller = StatusBarController()
        let header = try XCTUnwrap(controller.menu.items.first?.view as? MenuStatusHeaderView)
        let originalSize = header.frame.size
        var reminder = ReminderState()
        reminder.receive(snapshot(.none, issue: .dockUnavailable))
        controller.update(reminder: reminder)
        header.layoutSubtreeIfNeeded()
        XCTAssertEqual(header.frame.size, originalSize)
        XCTAssertFalse(controller.menu.items.contains { $0.title == "Preview Reminder" })
        let help = try XCTUnwrap(controller.menu.items.first { $0.title == "Help & Diagnostics" }?.submenu)
        XCTAssertTrue(help.items.contains { $0.title == "Preview Reminder" })
    }

    func testFastCadenceDoesNotOverwriteSelectedIdleInterval() {
        let controller = StatusBarController()
        controller.update(reminder: ReminderState(), pollingInterval: 10, effectiveInterval: 1)
        XCTAssertEqual(controller.intervalItemForTesting.title, "Idle Check Interval: 10s")
        XCTAssertEqual(controller.statusDetailForTesting, "Monitoring · every 1s")
    }

    func testIntervalsAreNestedAndOnlyCurrentIntervalIsChecked() {
        let controller = StatusBarController()
        controller.update(reminder: ReminderState(), pollingInterval: 5)
        let parent = controller.intervalItemForTesting
        XCTAssertEqual(parent.title, "Check Interval: 5s")
        XCTAssertEqual(parent.submenu?.items.filter { $0.state == .on }.map(\.title), ["5 Seconds"])
        XCTAssertFalse(controller.menu.items.contains { $0.title == "5 Seconds" })
    }

    func testMissingPermissionHasPriorityOverPauseAndUnread() {
        let controller = StatusBarController()
        var reminder = ReminderState()
        reminder.receive(snapshot(.hasUnread(count: 2)))
        reminder.pause(minutes: nil)
        controller.update(reminder: reminder, permissionRequired: true)
        XCTAssertEqual(controller.symbolForTesting, "exclamationmark.triangle")
        XCTAssertEqual(controller.statusTitleForTesting, "U: Permission needed")
    }

    func testDetectionFailureIsNotPresentedAsNoUnread() {
        let controller = StatusBarController()
        var reminder = ReminderState()
        reminder.receive(snapshot(.none, issue: .dockUnavailable))
        controller.update(reminder: reminder)
        XCTAssertEqual(controller.statusTitleForTesting, "U: Detection unavailable")
        XCTAssertEqual(controller.symbolForTesting, "exclamationmark.triangle")
    }

    private func snapshot(_ unread: UnreadState, issue: MonitoringIssue? = nil) -> AppMonitorSnapshot {
        AppMonitorSnapshot(providerID: "u", appName: "U", isInstalled: true,
                           isRunning: true, unreadState: unread, monitoringIssue: issue)
    }
}
