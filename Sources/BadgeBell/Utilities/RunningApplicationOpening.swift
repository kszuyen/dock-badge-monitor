import AppKit

public protocol AppLocating: Sendable {
    func appIsInstalled(bundleIdentifier: String) -> Bool
    func appIsRunning(bundleIdentifier: String) -> Bool
}

public protocol AppOpening: Sendable {
    func open(bundleIdentifier: String)
}

public struct WorkspaceAppLocator: AppLocating {
    public init() {}

    public func appIsInstalled(bundleIdentifier: String) -> Bool {
        MainActor.assumeIsolated {
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) != nil
        }
    }

    public func appIsRunning(bundleIdentifier: String) -> Bool {
        MainActor.assumeIsolated {
            NSWorkspace.shared.runningApplications.contains { application in
                application.bundleIdentifier == bundleIdentifier
            }
        }
    }
}

public struct WorkspaceAppOpener: AppOpening {
    public init() {}

    public func open(bundleIdentifier: String) {
        MainActor.assumeIsolated {
            guard let applicationURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
                return
            }

            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true

            NSWorkspace.shared.openApplication(at: applicationURL, configuration: configuration) { application, _ in
                application?.activate()
            }
        }
    }
}
