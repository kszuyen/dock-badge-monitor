import XCTest
@testable import BadgeBell

final class ReminderStateTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)
    private func snapshot(_ count: Int?, issue: MonitoringIssue? = nil) -> AppMonitorSnapshot {
        AppMonitorSnapshot(providerID: "u", appName: "U", isInstalled: true, isRunning: true,
                           unreadState: count.map { .hasUnread(count: $0) } ?? .none, monitoringIssue: issue)
    }

    func testDismissDoesNotAcknowledgeUnreadOrRepeatOnIdenticalPoll() {
        var state = ReminderState()
        state.receive(snapshot(3), now: now)
        XCTAssertTrue(state.isVisible)
        state.hide()
        state.receive(snapshot(3), now: now)
        XCTAssertTrue(state.hasUnread)
        XCTAssertFalse(state.isVisible)
        state.receive(snapshot(4), now: now)
        XCTAssertTrue(state.isVisible)
    }

    func testReadingMessagesUpdatesVisibleCountAndClosesWhenAllAreRead() {
        var state = ReminderState()
        state.receive(snapshot(5), now: now)
        state.receive(snapshot(2), now: now.addingTimeInterval(1))
        XCTAssertTrue(state.isVisible)
        XCTAssertEqual(state.displaySnapshot?.unreadState, .hasUnread(count: 2))
        XCTAssertEqual(state.detectedAt, now)
        state.receive(snapshot(nil), now: now.addingTimeInterval(2))
        XCTAssertFalse(state.isVisible)
        XCTAssertFalse(state.hasUnread)
    }

    func testReadingSomeMessagesDoesNotReopenDismissedReminder() {
        var state = ReminderState()
        state.receive(snapshot(5))
        state.hide()
        state.receive(snapshot(2))
        XCTAssertFalse(state.isVisible)
        XCTAssertEqual(state.snapshot?.unreadState, .hasUnread(count: 2))
    }

    func testResumeRedisplaysExistingUnreadWithoutCountChange() {
        var state = ReminderState()
        state.receive(snapshot(3))
        state.pause(minutes: nil)
        state.receive(snapshot(3))
        XCTAssertFalse(state.isVisible)
        state.resume()
        state.receive(snapshot(3))
        XCTAssertTrue(state.isVisible)
        XCTAssertFalse(state.isPaused)
    }

    func testTimedPauseExpiresAfterSleepAndChecksCurrentUnread() {
        var state = ReminderState()
        state.receive(snapshot(3), now: now)
        state.pause(minutes: 10, now: now)
        XCTAssertFalse(state.expirePause(now: now.addingTimeInterval(599)))
        XCTAssertTrue(state.expirePause(now: now.addingTimeInterval(3600)))
        state.receive(snapshot(3), now: now.addingTimeInterval(3600))
        XCTAssertTrue(state.isVisible)
        XCTAssertNil(state.pauseUntil)
    }

    func testRestoredPauseDeadlineExpiresAndIndefinitePauseStaysPaused() {
        var timed = ReminderState(isPaused: true, pauseUntil: now.addingTimeInterval(-1))
        XCTAssertTrue(timed.expirePause(now: now))
        var indefinite = ReminderState(isPaused: true)
        XCTAssertFalse(indefinite.expirePause(now: now))
        XCTAssertTrue(indefinite.isPaused)
    }

    func testPreviewDoesNotUnpauseOrCreateUnreadState() {
        var state = ReminderState(isPaused: true)
        state.preview(now: now)
        XCTAssertTrue(state.isVisible)
        XCTAssertTrue(state.isPreview)
        XCTAssertTrue(state.isPaused)
        XCTAssertFalse(state.hasUnread)
        state.receive(snapshot(nil))
        XCTAssertTrue(state.isVisible)
        state.hide()
        XCTAssertFalse(state.isVisible)
        XCTAssertTrue(state.isPaused)
    }

    func testClearingUnreadClosesRealReminder() {
        var state = ReminderState()
        state.receive(snapshot(2))
        state.receive(snapshot(nil))
        XCTAssertFalse(state.isVisible)
        XCTAssertFalse(state.hasUnread)
    }

    func testFailureHidesStaleCardAndRecoveryRestoresExistingUnread() {
        var state = ReminderState()
        state.receive(snapshot(2))
        state.receive(snapshot(nil, issue: .dockUnavailable))
        XCTAssertFalse(state.isVisible)
        state.receive(snapshot(2))
        XCTAssertTrue(state.isVisible)
    }

    func testResumeWithNoUnreadDoesNotShowAnEmptyReminder() {
        var state = ReminderState(isPaused: true)
        state.resume()
        state.receive(snapshot(nil))
        XCTAssertFalse(state.isVisible)
    }
}
