import Foundation

/// The persistent plist controls the next login; the loaded job supervises this session.
struct LaunchAgentManager {
    static let label = "io.github.kszuyen.badgebell.monitor"
    static let installedAppPath = "/Applications/BadgeBell.app"

    let homeDirectory: URL

    init(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.homeDirectory = homeDirectory
    }

    var plistURL: URL {
        homeDirectory.appendingPathComponent("Library/LaunchAgents/\(Self.label).plist")
    }

    var logsDirectory: URL {
        homeDirectory.appendingPathComponent("Library/Logs/BadgeBell")
    }

    var launchAtLogin: Bool { FileManager.default.fileExists(atPath: plistURL.path) }

    var configuration: [String: Any] {
        [
            "Label": Self.label,
            "ProgramArguments": [Self.installedAppPath + "/Contents/MacOS/BadgeBell", "--managed"],
            "RunAtLoad": true,
            "KeepAlive": ["SuccessfulExit": false],
            "ThrottleInterval": 30,
            "LimitLoadToSessionType": "Aqua",
            "ProcessType": "Interactive",
            "StandardOutPath": logsDirectory.appendingPathComponent("monitor.log").path,
            "StandardErrorPath": logsDirectory.appendingPathComponent("monitor.log").path,
        ]
    }

    func setLaunchAtLogin(_ enabled: Bool) throws {
        if enabled {
            try writeConfiguration(to: plistURL)
        } else if launchAtLogin {
            try FileManager.default.removeItem(at: plistURL)
        }
    }

    func prepareLogs() throws {
        try FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
        let logURL = logsDirectory.appendingPathComponent("monitor.log")
        if let attributes = try? FileManager.default.attributesOfItem(atPath: logURL.path),
           let size = attributes[.size] as? NSNumber, size.intValue > 1_048_576 {
            let previous = logsDirectory.appendingPathComponent("monitor.previous.log")
            if FileManager.default.fileExists(atPath: previous.path) {
                try FileManager.default.removeItem(at: previous)
            }
            try FileManager.default.moveItem(at: logURL, to: previous)
        }
    }

    func startManagedApp() throws {
        try prepareLogs()
        let domain = "gui/\(getuid())"
        let service = "\(domain)/\(Self.label)"
        // kickstart leaves an already-running instance alone (no -k).
        if try launchctl(["print", service]) == 0 {
            guard try launchctl(["kickstart", service]) == 0 else {
                throw LaunchError.commandFailed("Cannot start the registered BadgeBell monitor.")
            }
            return
        }

        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("BadgeBell-\(UUID().uuidString).plist")
        let source = launchAtLogin ? plistURL : temporaryURL
        if !launchAtLogin { try writeConfiguration(to: source) }
        defer { if source == temporaryURL { try? FileManager.default.removeItem(at: source) } }
        guard try launchctl(["bootstrap", domain, source.path]) == 0 else {
            throw LaunchError.commandFailed("Cannot register BadgeBell. Check System Settings > General > Login Items & Extensions.")
        }
    }

    private func writeConfiguration(to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try PropertyListSerialization.data(fromPropertyList: configuration, format: .xml, options: 0)
        try data.write(to: url, options: .atomic)
    }

    private func launchctl(_ arguments: [String]) throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }

    enum LaunchError: LocalizedError {
        case commandFailed(String)
        var errorDescription: String? {
            switch self { case .commandFailed(let message): message }
        }
    }
}

enum AppLog {
    static func write(_ message: String) {
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(message)\n"
        FileHandle.standardError.write(Data(line.utf8))
    }
}
