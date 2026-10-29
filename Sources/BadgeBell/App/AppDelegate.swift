import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var provider: CyberLinkUProvider?
    private var preferences: PreferencesStore?
    private var alertController: FloatingAlertController?
    private var statusBarController: StatusBarController?
    private var scheduler: MonitorScheduler?
    private var permissionTimer: Timer?
    private let launchAgent = LaunchAgentManager()
    private var permissionGranted = false
    private var lastSnapshot: AppMonitorSnapshot?
    private let accessibilityPermissionChecker: AccessibilityPermissionChecking = SystemAccessibilityPermissionChecker()

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppLog.write("BadgeBell started, version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development").")
        NSApplication.shared.setActivationPolicy(.accessory)

        let provider = CyberLinkUProvider()
        let preferences = PreferencesStore()
        let alertController = FloatingAlertController(openAction: {
            provider.openApp()
        })
        let statusBarController = StatusBarController(
            openU: {
                provider.openApp()
            },
            dismissAlert: {
                alertController.dismiss()
            },
            quit: {
                NSApplication.shared.terminate(nil)
            },
            pollingInterval: preferences.pollingInterval,
            setPollingInterval: { [weak self] interval in
                self?.updatePollingInterval(interval)
            },
            alertsPaused: preferences.alertsPaused,
            setAlertsPaused: { [weak self] alertsPaused in
                self?.updateAlertsPaused(alertsPaused)
            },
            launchAtLogin: launchAgent.launchAtLogin,
            setLaunchAtLogin: { [weak self] enabled in
                guard let self else { return false }
                do {
                    try self.launchAgent.setLaunchAtLogin(enabled)
                    AppLog.write("Launch at login: \(enabled).")
                    return true
                } catch {
                    AppLog.write("Cannot change launch at login: \(error.localizedDescription)")
                    Task { @MainActor in
                        let alert = NSAlert()
                        alert.messageText = "Could not change Launch at Login"
                        alert.informativeText = error.localizedDescription
                        alert.runModal()
                    }
                    return false
                }
            },
            openAccessibilitySettings: {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            },
            openDiagnostics: { [weak self] in
                guard let self else { return }
                try? FileManager.default.createDirectory(at: self.launchAgent.logsDirectory, withIntermediateDirectories: true)
                NSWorkspace.shared.open(self.launchAgent.logsDirectory)
            }
        )
        let providers: [AppMonitorProvider] = preferences.isProviderEnabled(provider.id) ? [provider] : []
        let scheduler = MonitorScheduler(providers: providers)

        scheduler.onSnapshot = { [weak self] snapshot in
            Task { @MainActor in
                if self?.lastSnapshot != snapshot {
                    AppLog.write("U state: installed=\(snapshot.isInstalled), running=\(snapshot.isRunning), unread=\(snapshot.unreadState.hasUnread).")
                    self?.lastSnapshot = snapshot
                }
                self?.statusBarController?.updateSnapshot(snapshot)
            }
        }
        scheduler.onUnreadTransition = { [weak self] transition in
            Task { @MainActor in
                guard self?.preferences?.alertsPaused == false else {
                    self?.statusBarController?.setAlertActive(false)
                    return
                }

                self?.statusBarController?.setAlertActive(true)
                self?.alertController?.show(snapshot: transition.snapshot)
            }
        }
        scheduler.onUnreadCleared = { [weak self] _ in
            Task { @MainActor in
                self?.alertController?.dismiss()
                self?.statusBarController?.setAlertActive(false)
            }
        }

        self.provider = provider
        self.preferences = preferences
        self.alertController = alertController
        self.statusBarController = statusBarController
        self.scheduler = scheduler

        startSchedulerWhenAccessibilityIsTrusted(prompt: true)
        schedulePermissionRecheck()
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppLog.write("BadgeBell exited normally; automatic restart is suppressed.")
        permissionTimer?.invalidate()
        scheduler?.stop()
    }

    private func startSchedulerWhenAccessibilityIsTrusted(prompt: Bool) {
        guard let scheduler, let preferences, let statusBarController else {
            return
        }

        guard accessibilityPermissionChecker.isTrusted(prompt: prompt) else {
            if permissionGranted { AppLog.write("Accessibility permission lost; monitoring stopped.") }
            permissionGranted = false
            scheduler.stop()
            alertController?.dismiss()
            statusBarController.setAccessibilityPermissionRequired()
            schedulePermissionRecheck()
            return
        }

        if !permissionGranted { AppLog.write("Accessibility permission granted; monitoring started.") }
        permissionGranted = true
        scheduler.start(interval: preferences.pollingInterval)
    }

    private func updatePollingInterval(_ interval: Double) {
        preferences?.pollingInterval = interval
        startSchedulerWhenAccessibilityIsTrusted(prompt: false)
    }

    private func updateAlertsPaused(_ alertsPaused: Bool) {
        AppLog.write("Alerts paused: \(alertsPaused).")
        preferences?.alertsPaused = alertsPaused
        if alertsPaused {
            alertController?.dismiss()
            statusBarController?.setAlertActive(false)
        }
    }

    private func schedulePermissionRecheck() {
        guard permissionTimer == nil else {
            return
        }

        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self,
                      self.accessibilityPermissionChecker.isTrusted(prompt: false) != self.permissionGranted else { return }
                self.startSchedulerWhenAccessibilityIsTrusted(prompt: false)
            }
        }
    }
}
