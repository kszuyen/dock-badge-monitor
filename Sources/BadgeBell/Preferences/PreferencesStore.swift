import Foundation

public enum AlertPosition: String, Sendable { case topRight; case topBar }

public struct PreferencesStore {
    private enum Keys {
        static let pollingInterval = "preferences.pollingInterval"
        static let alertPosition = "preferences.alertPosition"
        static let launchAtLogin = "preferences.launchAtLogin"
        static let pauseUntil = "preferences.pauseUntil"
        static let reminderScreen = "preferences.reminderScreen"
        static let showInFullScreen = "preferences.showInFullScreen"
        static let alertsPaused = "preferences.alertsPaused"

        static func providerEnabled(_ providerID: String) -> String {
            "preferences.provider.\(providerID).enabled"
        }
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func isProviderEnabled(_ providerID: String) -> Bool {
        let key = Keys.providerEnabled(providerID)
        guard defaults.object(forKey: key) != nil else {
            return true
        }

        return defaults.bool(forKey: key)
    }

    public func setProviderEnabled(_ enabled: Bool, providerID: String) {
        defaults.set(enabled, forKey: Keys.providerEnabled(providerID))
    }

    public var pollingInterval: Double {
        get {
            guard defaults.object(forKey: Keys.pollingInterval) != nil else {
                return 2.0
            }

            return defaults.double(forKey: Keys.pollingInterval)
        }
        set {
            defaults.set(max(1.0, newValue), forKey: Keys.pollingInterval)
        }
    }

    public var alertPosition: AlertPosition {
        get {
            guard
                let rawValue = defaults.string(forKey: Keys.alertPosition),
                let position = AlertPosition(rawValue: rawValue)
            else {
                return .topRight
            }

            return position
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.alertPosition)
        }
    }

    public var launchAtLogin: Bool {
        get {
            defaults.bool(forKey: Keys.launchAtLogin)
        }
        set {
            defaults.set(newValue, forKey: Keys.launchAtLogin)
        }
    }

    public var pauseUntil: Date? {
        get { defaults.object(forKey: Keys.pauseUntil) as? Date }
        set { defaults.set(newValue, forKey: Keys.pauseUntil) }
    }

    public var reminderScreen: String {
        get { defaults.string(forKey: Keys.reminderScreen) ?? "active" }
        set { defaults.set(newValue, forKey: Keys.reminderScreen) }
    }

    public var showInFullScreen: Bool {
        get { defaults.object(forKey: Keys.showInFullScreen) == nil || defaults.bool(forKey: Keys.showInFullScreen) }
        set { defaults.set(newValue, forKey: Keys.showInFullScreen) }
    }

    public var alertsPaused: Bool {
        get {
            defaults.bool(forKey: Keys.alertsPaused)
        }
        set {
            defaults.set(newValue, forKey: Keys.alertsPaused)
        }
    }
}
