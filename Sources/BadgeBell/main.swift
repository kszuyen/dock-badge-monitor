import AppKit

if CommandLine.arguments.contains("--enable-login") || CommandLine.arguments.contains("--disable-login") {
    do {
        try LaunchAgentManager().setLaunchAtLogin(CommandLine.arguments.contains("--enable-login"))
    } catch {
        AppLog.write("Cannot change launch at login: \(error.localizedDescription)")
        exit(1)
    }
} else if Bundle.main.bundleURL.path == LaunchAgentManager.installedAppPath,
   !CommandLine.arguments.contains("--managed") {
    do {
        try LaunchAgentManager().startManagedApp()
    } catch {
        AppLog.write("Startup failed: \(error.localizedDescription)")
        let alert = NSAlert()
        alert.messageText = "BadgeBell could not start"
        alert.informativeText = error.localizedDescription
        alert.runModal()
    }
} else {
    BadgeBellApplication.run()
}
