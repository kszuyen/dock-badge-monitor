import AppKit

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
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
    private var launchAtLoginMenuItem: NSMenuItem?
    private var launchAtLogin = false
    private var setLaunchAtLogin: @MainActor (Bool) -> Bool = { _ in true }
    private var openAccessibilitySettings: @MainActor () -> Void = {}
    private var openDiagnostics: @MainActor () -> Void = {}
    private var menuIsTracking = false
    private var trackingGeneration = 0
    private var pendingStatusTitle = "U: Checking"
    private var alertActive = false
    private var permissionRequired = false
    private var latestSnapshot: AppMonitorSnapshot?

    init(
        openU: @escaping @MainActor () -> Void,
        dismissAlert: @escaping @MainActor () -> Void,
        quit: @escaping @MainActor () -> Void,
        pollingInterval: Double = 2.0,
        setPollingInterval: @escaping @MainActor (Double) -> Void = { _ in },
        alertsPaused: Bool = false,
        setAlertsPaused: @escaping @MainActor (Bool) -> Void = { _ in },
        launchAtLogin: Bool = false,
        setLaunchAtLogin: @escaping @MainActor (Bool) -> Bool = { _ in true },
        openAccessibilitySettings: @escaping @MainActor () -> Void = {},
        openDiagnostics: @escaping @MainActor () -> Void = {}
    ) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: 48)
        self.statusMenuItem = NSMenuItem(title: "U: Checking", action: nil, keyEquivalent: "")
        self.openU = openU
        self.dismissAlert = dismissAlert
        self.quit = quit
        self.pollingInterval = pollingInterval
        self.setPollingInterval = setPollingInterval
        self.alertsPaused = alertsPaused
        self.setAlertsPaused = setAlertsPaused
        self.launchAtLogin = launchAtLogin
        self.setLaunchAtLogin = setLaunchAtLogin
        self.openAccessibilitySettings = openAccessibilitySettings
        self.openDiagnostics = openDiagnostics

        super.init()

        configureStatusItem()
    }

    func setAlertActive(_ isActive: Bool) {
        alertActive = isActive
        applyPresentation()
    }

    func updateSnapshot(_ snapshot: AppMonitorSnapshot) {
        permissionRequired = false
        latestSnapshot = snapshot
        updateStatusTitle()
    }

    func setAccessibilityPermissionRequired() {
        permissionRequired = true
        updateStatusTitle()
    }

    private func updateStatusTitle() {
        if permissionRequired {
            pendingStatusTitle = "U: Accessibility permission needed"
        } else if let snapshot = latestSnapshot {
            if !snapshot.isInstalled { pendingStatusTitle = "U: Not installed" }
            else if !snapshot.isRunning { pendingStatusTitle = "U: Not running" }
            else if alertsPaused { pendingStatusTitle = "U: Monitoring (alerts paused)" }
            else { pendingStatusTitle = snapshot.unreadState.hasUnread ? "U: Unread" : "U: Monitoring" }
        }
        applyPresentation()
    }

    // AppKit can repeatedly invalidate menu row layout when titles change during tracking.
    // Coalesce updates and apply only changed values after the tracking loop exits.
    private func applyPresentation() {
        guard !menuIsTracking else { return }
        if statusMenuItem.title != pendingStatusTitle { statusMenuItem.title = pendingStatusTitle }
        let title = permissionRequired ? "Bell?" : (alertActive && !alertsPaused ? "Bell!" : "Bell")
        if statusItem.button?.title != title { statusItem.button?.title = title }
        let pauseTitle = alertsPaused ? "Resume Alerts" : "Pause Alerts"
        if alertsPausedMenuItem?.title != pauseTitle { alertsPausedMenuItem?.title = pauseTitle }
        let pausedState: NSControl.StateValue = alertsPaused ? .on : .off
        if alertsPausedMenuItem?.state != pausedState { alertsPausedMenuItem?.state = pausedState }
        let loginState: NSControl.StateValue = launchAtLogin ? .on : .off
        if launchAtLoginMenuItem?.state != loginState { launchAtLoginMenuItem?.state = loginState }
        for (interval, item) in pollingIntervalMenuItems {
            let state: NSControl.StateValue = interval == pollingInterval ? .on : .off
            if item.state != state { item.state = state }
        }
        statusItem.button?.setAccessibilityLabel("BadgeBell. " + pendingStatusTitle)
    }

    func menuWillOpen(_ menu: NSMenu) {
        trackingGeneration &+= 1
        menuIsTracking = true
    }

    func menuDidClose(_ menu: NSMenu) {
        // Keep updates frozen until AppKit has unwound the menu event loop.
        let generation = trackingGeneration
        DispatchQueue.main.async { [weak self] in
            guard let self, self.trackingGeneration == generation else { return }
            self.menuIsTracking = false
            self.applyPresentation()
        }
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
        menu.delegate = self
        menu.autoenablesItems = false

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
        let loginItem = menuItem(title: "Launch at Login", action: #selector(launchAtLoginSelected))
        launchAtLoginMenuItem = loginItem
        menu.addItem(loginItem)
        menu.addItem(menuItem(title: "Open Accessibility Settings", action: #selector(accessibilitySettingsSelected)))
        menu.addItem(menuItem(title: "Open Diagnostic Logs", action: #selector(diagnosticsSelected)))
        menu.addItem(.separator())
        menu.addItem(menuItem(title: "Quit BadgeBell", action: #selector(quitSelected)))
        applyPresentation()

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
        updateStatusTitle()
    }

    private func updatePollingIntervalSelection() { applyPresentation() }

    private func updateAlertsPausedSelection() { applyPresentation() }

    @objc private func launchAtLoginSelected() {
        let enabled = !launchAtLogin
        if setLaunchAtLogin(enabled) {
            launchAtLogin = enabled
            applyPresentation()
        }
    }

    @objc private func accessibilitySettingsSelected() { openAccessibilitySettings() }
    @objc private func diagnosticsSelected() { openDiagnostics() }

    @objc private func quitSelected() {
        quit()
    }
}
