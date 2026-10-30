import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let provider = CyberLinkUProvider()
    private var preferences = PreferencesStore()
    private let launchAgent = LaunchAgentManager()
    private var reminder = ReminderState()
    private var alertController: FloatingAlertController!
    private var statusBar: StatusBarController!
    private var scheduler: MonitorScheduler!
    private var maintenanceTimer: Timer?
    private var permissionGranted = false
    private var effectiveInterval: Double?
    private var activationObserver: NSObjectProtocol?
    private var lastLoggedSnapshot: AppMonitorSnapshot?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppLog.write("BadgeBell started, version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development").")
        NSApp.setActivationPolicy(.accessory)
        reminder = ReminderState(isPaused: preferences.alertsPaused, pauseUntil: preferences.pauseUntil)
        if reminder.expirePause() { persistPause() }
        alertController = FloatingAlertController(
            openAction: { [weak self] in self?.openU() },
            dismissAction: { [weak self] in self?.hideReminder() },
            snoozeAction: { [weak self] in self?.pause(minutes: 10) }
        )
        var actions = StatusBarController.Actions()
        actions.openU = { [weak self] in self?.openU() }
        actions.hide = { [weak self] in self?.hideReminder() }
        actions.pause = { [weak self] minutes in self?.pause(minutes: minutes) }
        actions.resume = { [weak self] in self?.resume() }
        actions.interval = { [weak self] interval in
            guard let self else { return }
            self.preferences.pollingInterval = interval
            self.updateCadence()
            self.refresh()
        }
        actions.login = { [weak self] enabled in
            guard let self else { return }
            do {
                try self.launchAgent.setLaunchAtLogin(enabled)
                AppLog.write("Launch at login: \(enabled).")
                self.refresh()
            } catch { self.showError("Could not change Launch at Login", error: error) }
        }
        actions.preview = { [weak self] in
            guard let self else { return }
            self.reminder.preview()
            self.refresh()
        }
        actions.accessibility = {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
        actions.diagnostics = { [weak self] in
            guard let self else { return }
            do {
                try FileManager.default.createDirectory(at: self.launchAgent.logsDirectory, withIntermediateDirectories: true)
                NSWorkspace.shared.open(self.launchAgent.logsDirectory)
            } catch { self.showError("Could not open diagnostic logs", error: error) }
        }
        actions.screen = { [weak self] screen in
            self?.preferences.reminderScreen = screen
            self?.alertController.invalidatePlacement()
            self?.refresh()
        }
        actions.fullScreen = { [weak self] enabled in
            self?.preferences.showInFullScreen = enabled
            self?.alertController.invalidatePlacement()
            self?.refresh()
        }
        actions.quit = { NSApp.terminate(nil) }
        statusBar = StatusBarController(actions: actions)
        scheduler = MonitorScheduler(providers: preferences.isProviderEnabled(provider.id) ? [provider] : [])
        scheduler.onSnapshot = { [weak self] snapshot in
            Task { @MainActor in self?.receive(snapshot) }
        }
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.permissionGranted else { return }
                if !self.updateCadence() { self.scheduler.pollOnce() }
            }
        }
        updatePermission(prompt: true)
        refresh()
        maintenanceTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.updatePermission(prompt: false)
                if self.reminder.expirePause() {
                    self.persistPause()
                    AppLog.write("Timed pause expired; checking existing unread activity.")
                    if self.permissionGranted { self.scheduler.pollOnce() }
                }
                self.refresh()
            }
        }
    }

    private func receive(_ snapshot: AppMonitorSnapshot) {
        guard permissionGranted else { return }
        if snapshot != lastLoggedSnapshot {
            AppLog.write("U state: running=\(snapshot.isRunning), unread=\(snapshot.unreadState.hasUnread), issue=\(snapshot.monitoringIssue?.rawValue ?? "none").")
            lastLoggedSnapshot = snapshot
        }
        reminder.receive(snapshot)
        refresh()
    }

    private func updatePermission(prompt: Bool) {
        let trusted = SystemAccessibilityPermissionChecker().isTrusted(prompt: prompt)
        guard trusted != permissionGranted else { return }
        permissionGranted = trusted
        if trusted {
            AppLog.write("Accessibility permission granted; monitoring started.")
            reminder.resumeAfterPermissionChange()
            updateCadence()
        } else {
            AppLog.write("Accessibility permission lost; monitoring stopped.")
            scheduler.stop()
            effectiveInterval = nil
            reminder.hide()
        }
    }

    private func pause(minutes: Double?) {
        reminder.pause(minutes: minutes)
        persistPause()
        AppLog.write("Alerts paused: \(minutes.map { "\(Int($0)) minutes" } ?? "until resumed").")
        refresh()
    }

    private func resume() {
        reminder.resume()
        persistPause()
        AppLog.write("Alerts resumed; checking existing unread activity.")
        if permissionGranted { scheduler.pollOnce() }
        refresh()
    }

    private func persistPause() {
        preferences.alertsPaused = reminder.isPaused
        preferences.pauseUntil = reminder.pauseUntil
    }

    private func hideReminder() {
        reminder.hide()
        refresh()
    }

    private func openU() {
        provider.openApp()
        hideReminder()
    }

    @discardableResult
    private func updateCadence() -> Bool {
        guard permissionGranted else { return false }
        let interval = MonitoringCadence.interval(
            preferred: preferences.pollingInterval,
            reminderVisible: reminder.isVisible && !reminder.isPreview,
            appIsActive: NSWorkspace.shared.frontmostApplication?.bundleIdentifier == provider.bundleIdentifier)
        guard interval != effectiveInterval else { return false }
        effectiveInterval = interval
        scheduler.start(interval: interval)
        return true
    }

    private func refresh() {
        updateCadence()
        statusBar.update(reminder: reminder, permissionRequired: !permissionGranted,
                         pollingInterval: preferences.pollingInterval, launchAtLogin: launchAgent.launchAtLogin,
                         screen: preferences.reminderScreen, showInFullScreen: preferences.showInFullScreen,
                         effectiveInterval: effectiveInterval)
        if reminder.isVisible, let snapshot = reminder.displaySnapshot {
            alertController.show(snapshot: snapshot, detectedAt: reminder.detectedAt, isPreview: reminder.isPreview,
                                 screenMode: preferences.reminderScreen, showInFullScreen: preferences.showInFullScreen)
        } else { alertController.dismiss() }
    }

    private func showError(_ title: String, error: Error) {
        AppLog.write("\(title): \(error.localizedDescription)")
        Task { @MainActor in
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = error.localizedDescription
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let activationObserver { NSWorkspace.shared.notificationCenter.removeObserver(activationObserver) }
        maintenanceTimer?.invalidate()
        scheduler?.stop()
        AppLog.write("BadgeBell exited normally; automatic restart is suppressed.")
    }
}
