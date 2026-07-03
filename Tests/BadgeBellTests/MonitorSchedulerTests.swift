import XCTest
@testable import BadgeBell

final class MonitorSchedulerTests: XCTestCase {
    func testEmitsWhenUnreadCountIncreases() {
        let provider = StubProvider(
            snapshots: [
                .none,
                .hasUnread(count: 1),
                .hasUnread(count: 2),
            ]
        )
        let scheduler = MonitorScheduler(providers: [provider])
        var transitions: [UnreadTransition] = []

        scheduler.onUnreadTransition = { transition in
            transitions.append(transition)
        }

        scheduler.pollOnce()
        scheduler.pollOnce()
        scheduler.pollOnce()

        XCTAssertEqual(
            transitions.map(\.snapshot.unreadState),
            [.hasUnread(count: 1), .hasUnread(count: 2)]
        )
    }

    func testDoesNotEmitWhenUnreadCountDecreases() {
        let provider = StubProvider(
            snapshots: [
                .none,
                .hasUnread(count: 2),
                .hasUnread(count: 1),
            ]
        )
        let scheduler = MonitorScheduler(providers: [provider])
        var transitions: [UnreadTransition] = []

        scheduler.onUnreadTransition = { transition in
            transitions.append(transition)
        }

        scheduler.pollOnce()
        scheduler.pollOnce()
        scheduler.pollOnce()

        XCTAssertEqual(
            transitions.map(\.snapshot.unreadState),
            [.hasUnread(count: 2)]
        )
    }

    func testAllowsFutureTransitionAfterReturningToNone() {
        let provider = StubProvider(
            snapshots: [
                .none,
                .hasUnread(count: 1),
                .none,
                .hasUnread(count: nil),
            ]
        )
        let scheduler = MonitorScheduler(providers: [provider])
        var transitions: [UnreadTransition] = []

        scheduler.onUnreadTransition = { transition in
            transitions.append(transition)
        }

        scheduler.pollOnce()
        scheduler.pollOnce()
        scheduler.pollOnce()
        scheduler.pollOnce()

        XCTAssertEqual(
            transitions.map(\.snapshot.unreadState),
            [.hasUnread(count: 1), .hasUnread(count: nil)]
        )
    }

    func testEmitsUnreadClearedWhenReturningToNone() {
        let provider = StubProvider(
            snapshots: [
                .none,
                .hasUnread(count: 1),
                .hasUnread(count: 1),
                .none,
            ]
        )
        let scheduler = MonitorScheduler(providers: [provider])
        var clearedSnapshots: [AppMonitorSnapshot] = []

        scheduler.onUnreadCleared = { snapshot in
            clearedSnapshots.append(snapshot)
        }

        scheduler.pollOnce()
        scheduler.pollOnce()
        scheduler.pollOnce()
        scheduler.pollOnce()

        XCTAssertEqual(clearedSnapshots.map(\.unreadState), [.none])
    }
}

private final class StubProvider: AppMonitorProvider, @unchecked Sendable {
    let id = "stub-provider"
    let appName = "Stub App"
    let bundleIdentifier = "com.example.stub"

    private var snapshots: [UnreadState]

    init(snapshots: [UnreadState]) {
        self.snapshots = snapshots
    }

    func snapshot() -> AppMonitorSnapshot {
        let unreadState = snapshots.removeFirst()

        return AppMonitorSnapshot(
            providerID: id,
            appName: appName,
            isInstalled: true,
            isRunning: true,
            unreadState: unreadState
        )
    }

    func openApp() {}
}
