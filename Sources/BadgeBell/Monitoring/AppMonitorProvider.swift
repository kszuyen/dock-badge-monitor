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

public struct AppMonitorSnapshot: Equatable, Sendable {
    public let providerID: String
    public let appName: String
    public let isInstalled: Bool
    public let isRunning: Bool
    public let unreadState: UnreadState

    public init(
        providerID: String,
        appName: String,
        isInstalled: Bool,
        isRunning: Bool,
        unreadState: UnreadState
    ) {
        self.providerID = providerID
        self.appName = appName
        self.isInstalled = isInstalled
        self.isRunning = isRunning
        self.unreadState = unreadState
    }
}

public protocol AppMonitorProvider: Sendable {
    var id: String { get }
    var appName: String { get }
    var bundleIdentifier: String { get }

    func snapshot() -> AppMonitorSnapshot
    func openApp()
}
