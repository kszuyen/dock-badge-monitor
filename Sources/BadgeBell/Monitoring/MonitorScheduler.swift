import Foundation

public struct UnreadTransition: Equatable {
    public let snapshot: AppMonitorSnapshot
}

public final class MonitorScheduler: @unchecked Sendable {
    private let providers: [AppMonitorProvider]
    private var lastUnreadStateByProviderID: [String: UnreadState]
    private var timer: Timer?

    public var onUnreadTransition: ((UnreadTransition) -> Void)?
    public var onUnreadCleared: ((AppMonitorSnapshot) -> Void)?
    public var onSnapshot: ((AppMonitorSnapshot) -> Void)?

    public init(providers: [AppMonitorProvider]) {
        self.providers = providers
        self.lastUnreadStateByProviderID = [:]
    }

    deinit {
        stop()
    }

    public func start(interval: TimeInterval) {
        stop()
        pollOnce()

        timer = Timer(timeInterval: max(interval, 1.0), repeats: true) { [weak self] _ in
            self?.pollOnce()
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    public func pollOnce() {
        for provider in providers {
            let snapshot = provider.snapshot()
            onSnapshot?(snapshot)
            guard snapshot.monitoringIssue == nil else { continue }

            let lastUnreadState = lastUnreadStateByProviderID[provider.id] ?? .none
            lastUnreadStateByProviderID[provider.id] = snapshot.unreadState

            if Self.shouldEmitUnreadTransition(from: lastUnreadState, to: snapshot.unreadState) {
                onUnreadTransition?(UnreadTransition(snapshot: snapshot))
            }

            if Self.shouldEmitUnreadCleared(from: lastUnreadState, to: snapshot.unreadState) {
                onUnreadCleared?(snapshot)
            }
        }
    }

    private static func shouldEmitUnreadTransition(from previous: UnreadState, to current: UnreadState) -> Bool {
        switch (previous, current) {
        case (.none, .hasUnread):
            true
        case (.hasUnread(let previousCount?), .hasUnread(let currentCount?)):
            currentCount > previousCount
        default:
            false
        }
    }

    private static func shouldEmitUnreadCleared(from previous: UnreadState, to current: UnreadState) -> Bool {
        switch (previous, current) {
        case (.hasUnread, .none):
            true
        default:
            false
        }
    }
}

/// Active reading and visible reminders use a short latency without changing the idle preference.
enum MonitoringCadence {
    static func interval(preferred: Double, reminderVisible: Bool, appIsActive: Bool) -> Double {
        reminderVisible || appIsActive ? 1 : max(1, preferred)
    }
}
