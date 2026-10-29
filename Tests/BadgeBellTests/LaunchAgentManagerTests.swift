import Foundation
import XCTest
@testable import BadgeBell

final class LaunchAgentManagerTests: XCTestCase {
    func testLoginTogglePersistsValidAgentAndRemovesItWithoutChangingRecoveryPolicy() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: home) }
        let manager = LaunchAgentManager(homeDirectory: home)
        XCTAssertFalse(manager.launchAtLogin)
        try manager.setLaunchAtLogin(true)
        let plist = try XCTUnwrap(PropertyListSerialization.propertyList(
            from: Data(contentsOf: manager.plistURL), format: nil
        ) as? [String: Any])
        XCTAssertEqual(plist["ProgramArguments"] as? [String], [
            "/Applications/BadgeBell.app/Contents/MacOS/BadgeBell", "--managed",
        ])
        XCTAssertEqual((plist["KeepAlive"] as? [String: Bool])?["SuccessfulExit"], false)
        XCTAssertEqual(plist["ThrottleInterval"] as? Int, 30)
        XCTAssertEqual(plist["RunAtLoad"] as? Bool, true)
        try manager.setLaunchAtLogin(false)
        XCTAssertFalse(manager.launchAtLogin)
        try manager.setLaunchAtLogin(false)
    }

    func testLogsRotateAtStartupWithoutDiscardingLatestLog() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: home) }
        let manager = LaunchAgentManager(homeDirectory: home)
        try manager.prepareLogs()
        let url = manager.logsDirectory.appendingPathComponent("monitor.log")
        let content = Data(repeating: 65, count: 1_048_577)
        try content.write(to: url)
        try manager.prepareLogs()
        XCTAssertEqual(try Data(contentsOf: manager.logsDirectory.appendingPathComponent("monitor.previous.log")), content)
    }
}
