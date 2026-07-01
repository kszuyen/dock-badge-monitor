import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var provider: CyberLinkUProvider?
    private var preferences: PreferencesStore?
    private var alertController: FloatingAlertController?
    private var statusBarController: StatusBarController?
    private var scheduler: MonitorScheduler?
    private var permissionTimer: Timer?
    private let accessibilityPermissionChecker: AccessibilityPermissionChecking = SystemAccessibilityPermissionChecker()

    func applicationDidFinishLaunching(_ notification: Notification) {
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
            }
        )
        let providers: [AppMonitorProvider] = preferences.isProviderEnabled(provider.id) ? [provider] : []
        let scheduler = MonitorScheduler(providers: providers)

        scheduler.onSnapshot = { [weak self] snapshot in
            Task { @MainActor in
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

        self.provider = provider
        self.preferences = preferences
        self.alertController = alertController
        self.statusBarController = statusBarController
        self.scheduler = scheduler

        startSchedulerWhenAccessibilityIsTrusted(prompt: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        permissionTimer?.invalidate()
        scheduler?.stop()
    }

    private func startSchedulerWhenAccessibilityIsTrusted(prompt: Bool) {
        guard let scheduler, let preferences, let statusBarController else {
            return
        }

        guard accessibilityPermissionChecker.isTrusted(prompt: prompt) else {
            statusBarController.setAccessibilityPermissionRequired()
            schedulePermissionRecheck()
            return
        }

        permissionTimer?.invalidate()
        permissionTimer = nil
        scheduler.start(interval: preferences.pollingInterval)
    }

    private func updatePollingInterval(_ interval: Double) {
        preferences?.pollingInterval = interval
        startSchedulerWhenAccessibilityIsTrusted(prompt: false)
    }

    private func updateAlertsPaused(_ alertsPaused: Bool) {
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
                self?.startSchedulerWhenAccessibilityIsTrusted(prompt: false)
            }
        }
    }
}
