import AppKit

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    struct Actions {
        var openU: () -> Void = {}
        var hide: () -> Void = {}
        var pause: (Double?) -> Void = { _ in }
        var resume: () -> Void = {}
        var interval: (Double) -> Void = { _ in }
        var login: (Bool) -> Void = { _ in }
        var preview: () -> Void = {}
        var accessibility: () -> Void = {}
        var diagnostics: () -> Void = {}
        var screen: (String) -> Void = { _ in }
        var fullScreen: (Bool) -> Void = { _ in }
        var quit: () -> Void = {}
    }

    let menu = NSMenu()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let heading = NSMenuItem(title: "U: Checking", action: nil, keyEquivalent: "")
    private let detail = NSMenuItem(title: "Starting monitoring…", action: nil, keyEquivalent: "")
    private let statusHeader = MenuStatusHeaderView()
    private let actions: Actions
    private var hideItem: NSMenuItem!
    private var openItem: NSMenuItem!
    private var pauseItem: NSMenuItem!
    private var intervalItem: NSMenuItem!
    private var loginItem: NSMenuItem!
    private var permissionItem: NSMenuItem!
    private var fullScreenItem: NSMenuItem!
    private let pauseMenu = NSMenu()
    private var intervals: [Double: NSMenuItem] = [:]
    private var screens: [String: NSMenuItem] = [:]
    private var reminder = ReminderState()
    private var permissionRequired = false
    private var pollingInterval: Double = 2
    private var login = false
    private var selectedScreen = "active"
    private var showInFullScreen = true
    private var isUnwinding = false
    private var openMenus = 0
    private var trackingGeneration = 0
    private var currentSymbol = ""

    init(actions: Actions = Actions()) {
        self.actions = actions
        super.init()
        configure()
        statusItem.menu = menu
        applyPresentation()
    }

    func update(reminder: ReminderState, permissionRequired: Bool = false,
                pollingInterval: Double = 2, launchAtLogin: Bool = false,
                screen: String = "active", showInFullScreen: Bool = true) {
        self.reminder = reminder
        self.permissionRequired = permissionRequired
        self.pollingInterval = pollingInterval
        login = launchAtLogin
        selectedScreen = screen
        self.showInFullScreen = showInFullScreen
        applyPresentation()
    }

    private func configure() {
        prepare(menu)
        heading.isEnabled = false
        heading.view = statusHeader
        detail.isEnabled = false
        menu.addItem(heading)
        permissionItem = item("Open Accessibility Settings…", #selector(accessibilitySelected), symbol: "lock.open", in: menu)
        menu.addItem(.separator())
        openItem = item("Open U", #selector(openSelected), in: menu)
        hideItem = item("Hide This Reminder", #selector(hideSelected), in: menu)
        pauseItem = item("Pause Alerts", #selector(resumeSelected), in: menu)
        prepare(pauseMenu)
        for minutes in [15, 30, 60] {
            let option = item(minutes == 60 ? "For 1 Hour" : "For \(minutes) Minutes", #selector(pauseSelected(_:)), in: pauseMenu)
            option.representedObject = Double(minutes)
        }
        pauseMenu.addItem(.separator())
        item("Until I Resume", #selector(pauseSelected(_:)), in: pauseMenu)

        menu.addItem(.separator())
        intervalItem = item("Check Interval: 2s", nil, in: menu)
        let intervalMenu = NSMenu()
        prepare(intervalMenu)
        for seconds in [1.0, 2.0, 5.0, 10.0] {
            let option = item("\(Int(seconds)) \(seconds == 1 ? "Second" : "Seconds")", #selector(intervalSelected(_:)), in: intervalMenu)
            option.representedObject = seconds
            intervals[seconds] = option
        }
        intervalItem.submenu = intervalMenu
        let placement = item("Reminder Display", nil, in: menu)
        let displayMenu = NSMenu()
        prepare(displayMenu)
        for (value, title) in [("active", "Screen with Pointer"), ("main", "Primary Screen")] {
            let option = item(title, #selector(screenSelected(_:)), in: displayMenu)
            option.representedObject = value
            screens[value] = option
        }
        displayMenu.addItem(.separator())
        fullScreenItem = item("Show over Full-Screen Apps", #selector(fullScreenSelected), in: displayMenu)
        placement.submenu = displayMenu
        loginItem = item("Launch at Login", #selector(loginSelected), in: menu)
        menu.addItem(.separator())
        let help = item("Help & Diagnostics", nil, in: menu)
        let helpMenu = NSMenu()
        prepare(helpMenu)
        item("Preview Reminder", #selector(previewSelected), in: helpMenu)
        helpMenu.addItem(.separator())
        item("Accessibility Settings…", #selector(accessibilitySelected), in: helpMenu)
        item("Diagnostic Logs…", #selector(diagnosticsSelected), in: helpMenu)
        helpMenu.addItem(.separator())
        item("About BadgeBell…", #selector(aboutSelected), in: helpMenu)
        help.submenu = helpMenu
        menu.addItem(.separator())
        item("Quit BadgeBell", #selector(quitSelected), in: menu, key: "q")
    }

    private func prepare(_ menu: NSMenu) {
        menu.delegate = self
        menu.autoenablesItems = false
    }

    @discardableResult
    private func item(_ title: String, _ action: Selector?, symbol: String? = nil,
                      in menu: NSMenu, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        if let symbol { item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) }
        menu.addItem(item)
        return item
    }

    // Never mutate any menu or status-button layout while a root or submenu is tracking.
    private func applyPresentation() {
        guard openMenus == 0, !isUnwinding else { return }
        let snapshot = reminder.snapshot
        let title: String
        if permissionRequired { title = "U: Permission needed" }
        else if snapshot?.monitoringIssue != nil { title = "U: Detection unavailable" }
        else if snapshot?.isInstalled == false { title = "U: Not installed" }
        else if snapshot?.isRunning == false { title = "U: Not running" }
        else if case .hasUnread(let count?) = snapshot?.unreadState { title = "U · \(count) unread" }
        else if reminder.hasUnread { title = "U: Unread" }
        else { title = snapshot == nil ? "U: Checking" : "U: No unread messages" }
        if heading.title != title {
            heading.title = title
        }
        let subtitle = permissionRequired ? "Enable Accessibility to monitor U" :
            snapshot?.monitoringIssue?.description ?? reminder.pauseDescription() ?? "Monitoring · every \(Int(pollingInterval))s"
        setTitle(subtitle, on: detail)
        statusHeader.update(title: title, detail: subtitle)
        permissionItem.isHidden = !permissionRequired && snapshot?.monitoringIssue == nil
        hideItem.isEnabled = reminder.isVisible
        openItem.isEnabled = snapshot?.isInstalled != false
        setTitle(reminder.isPaused ? "Resume Alerts" : "Pause Alerts", on: pauseItem)
        pauseItem.submenu = reminder.isPaused ? nil : pauseMenu
        pauseItem.state = .off
        setTitle("Check Interval: \(Int(pollingInterval))s", on: intervalItem)
        for (seconds, item) in intervals { item.state = seconds == pollingInterval ? .on : .off }
        for (screen, item) in screens { item.state = screen == selectedScreen ? .on : .off }
        loginItem.state = login ? .on : .off
        fullScreenItem.state = showInFullScreen ? .on : .off
        let symbol = permissionRequired || snapshot?.monitoringIssue != nil ? "exclamationmark.triangle" :
            reminder.isPaused ? "bell.slash" : reminder.hasUnread ? "bell.badge" : "bell"
        if currentSymbol != symbol {
            let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
            image?.isTemplate = true
            statusItem.button?.image = image
            currentSymbol = symbol
        }
        let description = "BadgeBell. \(title). \(subtitle)"
        if statusItem.button?.toolTip != description {
            statusItem.button?.toolTip = description
            statusItem.button?.setAccessibilityLabel(description)
        }
    }

    private func setTitle(_ title: String, on item: NSMenuItem) {
        if item.title != title { item.title = title }
    }

    func menuWillOpen(_ menu: NSMenu) {
        trackingGeneration &+= 1
        openMenus += 1
    }

    func menuDidClose(_ menu: NSMenu) {
        isUnwinding = true
        openMenus = max(0, openMenus - 1)
        let generation = trackingGeneration
        DispatchQueue.main.async { [weak self] in
            guard let self, self.trackingGeneration == generation else { return }
            self.isUnwinding = false
            self.applyPresentation()
        }
    }

    var statusTitleForTesting: String { heading.title }
    var statusDetailForTesting: String { detail.title }
    var symbolForTesting: String { currentSymbol }
    var pauseItemForTesting: NSMenuItem { pauseItem }
    var hideItemForTesting: NSMenuItem { hideItem }
    var intervalItemForTesting: NSMenuItem { intervalItem }

    @objc private func openSelected() { actions.openU() }
    @objc private func hideSelected() { actions.hide() }
    @objc private func pauseSelected(_ sender: NSMenuItem) { actions.pause(sender.representedObject as? Double) }
    @objc private func resumeSelected() { actions.resume() }
    @objc private func intervalSelected(_ sender: NSMenuItem) {
        if let interval = sender.representedObject as? Double { actions.interval(interval) }
    }
    @objc private func loginSelected() { actions.login(!login) }
    @objc private func previewSelected() { actions.preview() }
    @objc private func accessibilitySelected() { actions.accessibility() }
    @objc private func diagnosticsSelected() { actions.diagnostics() }
    @objc private func screenSelected(_ sender: NSMenuItem) {
        if let screen = sender.representedObject as? String { actions.screen(screen) }
    }
    @objc private func fullScreenSelected() { actions.fullScreen(!showInFullScreen) }
    @objc private func aboutSelected() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "BadgeBell", .credits: NSAttributedString(string: "Persistent unread reminders for CyberLink U.")])
    }
    @objc private func quitSelected() { actions.quit() }
}
