import AppKit
import ApplicationServices
import Foundation

public protocol BadgeReading: Sendable {
    func unreadState(bundleIdentifier: String) -> UnreadState
}

public struct DockBadgeReader: BadgeReading {
    private let targetAppName: String?
    private let snapshotProvider: any DockItemSnapshotProviding

    public init(
        targetAppName: String? = nil,
        snapshotProvider: any DockItemSnapshotProviding = SystemDockItemSnapshotProvider()
    ) {
        self.targetAppName = targetAppName
        self.snapshotProvider = snapshotProvider
    }

    public func unreadState(bundleIdentifier: String) -> UnreadState {
        for snapshot in snapshotProvider.dockItemSnapshots() where snapshot.matches(
            bundleIdentifier: bundleIdentifier,
            targetAppName: targetAppName
        ) {
            return Self.parseStatusLabel(snapshot.combinedText)
        }

        return .none
    }

    static func parseStatusLabel(_ statusLabel: String) -> UnreadState {
        let normalizedLabel = statusLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedLabel.isEmpty else {
            return .none
        }

        let numbers = normalizedLabel.matches(of: /\d+/).compactMap { Int($0.output) }
        if let unreadCount = numbers.first(where: { $0 > 0 }) {
            return .hasUnread(count: unreadCount)
        }

        let lowercasedLabel = normalizedLabel.lowercased()
        let unreadKeywords = ["unread", "notification", "notifications", "badge", "new"]
        if unreadKeywords.contains(where: { lowercasedLabel.contains($0) }) {
            return .hasUnread(count: nil)
        }

        return .none
    }
}

public struct DockItemSnapshot: Equatable, Sendable {
    public let identifier: String
    public let title: String
    public let description: String
    public let statusLabel: String
    public let accessibleDescription: String

    public init(
        identifier: String,
        title: String,
        description: String,
        statusLabel: String,
        accessibleDescription: String
    ) {
        self.identifier = identifier
        self.title = title
        self.description = description
        self.statusLabel = statusLabel
        self.accessibleDescription = accessibleDescription
    }

    var combinedText: String {
        [identifier, title, description, statusLabel, accessibleDescription]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    var hasText: Bool {
        !combinedText.isEmpty
    }

    func matches(bundleIdentifier: String, targetAppName: String?) -> Bool {
        let normalizedBundleIdentifier = bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !normalizedBundleIdentifier.isEmpty && combinedText.lowercased().contains(normalizedBundleIdentifier) {
            return true
        }

        guard let targetAppName, !targetAppName.isEmpty else {
            return false
        }

        return [title, description, accessibleDescription].contains { field in
            field.matchesDockItemName(targetAppName)
        }
    }
}

public protocol DockItemSnapshotProviding: Sendable {
    func dockItemSnapshots() -> [DockItemSnapshot]
}

public struct SystemDockItemSnapshotProvider: DockItemSnapshotProviding {
    private let maxTraversalDepth: Int

    public init(maxTraversalDepth: Int = 5) {
        self.maxTraversalDepth = maxTraversalDepth
    }

    public func dockItemSnapshots() -> [DockItemSnapshot] {
        guard let dockApplication = NSRunningApplication
            .runningApplications(withBundleIdentifier: "com.apple.dock")
            .first
        else {
            return []
        }

        let dockElement = AXUIElementCreateApplication(dockApplication.processIdentifier)
        var snapshots: [DockItemSnapshot] = []
        collectSnapshots(from: dockElement, depth: 0, into: &snapshots)
        return snapshots
    }

    private func collectSnapshots(from element: AXUIElement, depth: Int, into snapshots: inout [DockItemSnapshot]) {
        guard depth <= maxTraversalDepth else {
            return
        }

        let snapshot = DockItemSnapshot(
            identifier: stringAttribute("AXIdentifier", from: element),
            title: stringAttribute(kAXTitleAttribute, from: element),
            description: stringAttribute(kAXDescriptionAttribute, from: element),
            statusLabel: stringAttribute("AXStatusLabel", from: element),
            accessibleDescription: stringAttribute("AXHelp", from: element)
        )

        if snapshot.hasText {
            snapshots.append(snapshot)
        }

        for child in children(of: element) {
            collectSnapshots(from: child, depth: depth + 1, into: &snapshots)
        }
    }

    private func children(of element: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value)
        guard error == .success, let value else {
            return []
        }

        return (value as? [AXUIElement]) ?? []
    }

    private func stringAttribute(_ attributeName: String, from element: AXUIElement) -> String {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attributeName as CFString, &value)
        guard error == .success, let value else {
            return ""
        }

        if let string = value as? String {
            return string
        }

        if let number = value as? NSNumber {
            return number.stringValue
        }

        return ""
    }
}

private extension String {
    func matchesDockItemName(_ targetAppName: String) -> Bool {
        self == targetAppName || hasPrefix("\(targetAppName),")
    }
}
