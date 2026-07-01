import AppKit

@MainActor
final class StatusBarController: NSObject {
    static let statusMenuItemTag = 1001
    private static let pollingIntervals = [1.0, 2.0, 5.0, 10.0]

    private let statusItem: NSStatusItem
    private let statusMenuItem: NSMenuItem
    private let openU: @MainActor () -> Void
    private let dismissAlert: @MainActor () -> Void
    private let quit: @MainActor () -> Void
    private let setPollingInterval: @MainActor (Double) -> Void
    private let setAlertsPaused: @MainActor (Bool) -> Void
    private var pollingInterval: Double
    private var alertsPaused: Bool
    private var pollingIntervalMenuItems: [Double: NSMenuItem] = [:]
    private var alertsPausedMenuItem: NSMenuItem?

    init(
        openU: @escaping @MainActor () -> Void,
        dismissAlert: @escaping @MainActor () -> Void,
        quit: @escaping @MainActor () -> Void,
        pollingInterval: Double = 2.0,
        setPollingInterval: @escaping @MainActor (Double) -> Void = { _ in },
        alertsPaused: Bool = false,
        setAlertsPaused: @escaping @MainActor (Bool) -> Void = { _ in }
    ) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusMenuItem = NSMenuItem(title: "U: Checking", action: nil, keyEquivalent: "")
        self.openU = openU
        self.dismissAlert = dismissAlert
        self.quit = quit
        self.pollingInterval = pollingInterval
        self.setPollingInterval = setPollingInterval
        self.alertsPaused = alertsPaused
        self.setAlertsPaused = setAlertsPaused

        super.init()

        configureStatusItem()
    }

    func setAlertActive(_ isActive: Bool) {
        statusItem.button?.title = isActive && !alertsPaused ? "Bell!" : "Bell"
    }

    func updateSnapshot(_ snapshot: AppMonitorSnapshot) {
        statusMenuItem.title = snapshot.unreadState.hasUnread ? "U: Unread" : "U: Idle"
    }

    func setAccessibilityPermissionRequired() {
        statusMenuItem.title = "U: Accessibility permission needed"
    }

    var statusTitleForTesting: String {
        statusMenuItem.title
    }

    var pollingIntervalStatesForTesting: [String: Bool] {
        pollingIntervalMenuItems.reduce(into: [:]) { states, item in
            states[item.value.title] = item.value.state == .on
        }
    }

    var alertsPausedTitleForTesting: String? {
        alertsPausedMenuItem?.title
    }

    func selectPollingIntervalForTesting(_ interval: Double) {
        guard let item = pollingIntervalMenuItems[interval] else {
            return
        }

        pollingIntervalSelected(item)
    }

    func toggleAlertsPausedForTesting() {
        guard let alertsPausedMenuItem else {
            return
        }

        alertsPausedSelected(alertsPausedMenuItem)
    }

    private func configureStatusItem() {
        statusItem.button?.title = "Bell"

        let menu = NSMenu()

        statusMenuItem.tag = Self.statusMenuItemTag
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        menu.addItem(.separator())
        menu.addItem(menuItem(title: "Open U", action: #selector(openUSelected)))
        menu.addItem(menuItem(title: "Dismiss Alert", action: #selector(dismissAlertSelected)))
        let pauseItem = menuItem(title: "", action: #selector(alertsPausedSelected(_:)))
        alertsPausedMenuItem = pauseItem
        updateAlertsPausedSelection()
        menu.addItem(pauseItem)
        menu.addItem(.separator())
        for interval in Self.pollingIntervals {
            let item = menuItem(title: "Check every \(Int(interval))s", action: #selector(pollingIntervalSelected(_:)))
            item.representedObject = interval
            pollingIntervalMenuItems[interval] = item
            menu.addItem(item)
        }
        updatePollingIntervalSelection()
        menu.addItem(.separator())
        menu.addItem(menuItem(title: "Quit BadgeBell", action: #selector(quitSelected)))

        statusItem.menu = menu
    }

    private func menuItem(title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func openUSelected() {
        openU()
    }

    @objc private func dismissAlertSelected() {
        dismissAlert()
        setAlertActive(false)
    }

    @objc private func pollingIntervalSelected(_ sender: NSMenuItem) {
        guard let interval = sender.representedObject as? Double else {
            return
        }

        pollingInterval = interval
        updatePollingIntervalSelection()
        setPollingInterval(interval)
    }

    @objc private func alertsPausedSelected(_ sender: NSMenuItem) {
        alertsPaused.toggle()
        updateAlertsPausedSelection()
        setAlertActive(false)
        setAlertsPaused(alertsPaused)
    }

    private func updatePollingIntervalSelection() {
        for (interval, item) in pollingIntervalMenuItems {
            item.state = interval == pollingInterval ? .on : .off
        }
    }

    private func updateAlertsPausedSelection() {
        alertsPausedMenuItem?.title = alertsPaused ? "Resume Alerts" : "Pause Alerts"
        alertsPausedMenuItem?.state = alertsPaused ? .on : .off
    }

    @objc private func quitSelected() {
        quit()
    }
}
