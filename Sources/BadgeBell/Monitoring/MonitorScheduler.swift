import Foundation

public struct UnreadTransition: Equatable {
    public let snapshot: AppMonitorSnapshot
}

public final class MonitorScheduler: @unchecked Sendable {
    private let providers: [AppMonitorProvider]
    private var lastUnreadStateByProviderID: [String: UnreadState]
    private var timer: Timer?

    public var onUnreadTransition: ((UnreadTransition) -> Void)?
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

        timer = Timer.scheduledTimer(withTimeInterval: max(interval, 1.0), repeats: true) { [weak self] _ in
            self?.pollOnce()
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    public func pollOnce() {
        for provider in providers {
            let snapshot = provider.snapshot()
            onSnapshot?(snapshot)

            let lastUnreadState = lastUnreadStateByProviderID[provider.id] ?? .none
            lastUnreadStateByProviderID[provider.id] = snapshot.unreadState

            if Self.shouldEmitUnreadTransition(from: lastUnreadState, to: snapshot.unreadState) {
                onUnreadTransition?(UnreadTransition(snapshot: snapshot))
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
}
