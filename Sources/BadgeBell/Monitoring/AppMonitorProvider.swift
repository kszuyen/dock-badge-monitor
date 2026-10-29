import Foundation

public enum UnreadState: Equatable, Sendable {
    case none
    case hasUnread(count: Int?)

    public var hasUnread: Bool {
        switch self {
        case .none:
            false
        case .hasUnread:
            true
        }
    }
}

public enum MonitoringIssue: String, Equatable, Sendable {
    case dockUnavailable
    case badgeUnavailable

    var description: String {
        switch self {
        case .dockUnavailable: "Cannot read Dock - check Accessibility permission"
        case .badgeUnavailable: "U badge unavailable - keep U in the Dock"
        }
    }
}

public struct BadgeReadResult: Sendable {
    public let unreadState: UnreadState
    public let issue: MonitoringIssue?

    public init(unreadState: UnreadState, issue: MonitoringIssue? = nil) {
        self.unreadState = unreadState
        self.issue = issue
    }
}

public struct AppMonitorSnapshot: Equatable, Sendable {
    public let providerID: String
    public let appName: String
    public let isInstalled: Bool
    public let isRunning: Bool
    public let unreadState: UnreadState
    public let monitoringIssue: MonitoringIssue?

    public init(
        providerID: String,
        appName: String,
        isInstalled: Bool,
        isRunning: Bool,
        unreadState: UnreadState,
        monitoringIssue: MonitoringIssue? = nil
    ) {
        self.providerID = providerID
        self.appName = appName
        self.isInstalled = isInstalled
        self.isRunning = isRunning
        self.unreadState = unreadState
        self.monitoringIssue = monitoringIssue
    }
}

public protocol AppMonitorProvider: Sendable {
    var id: String { get }
    var appName: String { get }
    var bundleIdentifier: String { get }

    func snapshot() -> AppMonitorSnapshot
    func openApp()
}
