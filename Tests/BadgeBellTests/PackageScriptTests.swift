import Foundation
import XCTest

final class PackageScriptTests: XCTestCase {
    func testPackageScriptSupportsDeveloperIDSigningIdentity() throws {
        let script = try String(
            contentsOfFile: "scripts/package-app.sh",
            encoding: .utf8
        )

        XCTAssertTrue(script.contains("BADGEBELL_CODESIGN_IDENTITY"))
        XCTAssertTrue(script.contains("BADGEBELL_LOCAL_CODESIGN_IDENTITY"))
        XCTAssertTrue(script.contains("BadgeBell Local Code Signing"))
        XCTAssertTrue(script.contains("--options runtime"))
        XCTAssertTrue(script.contains("--timestamp"))
    }

    func testLocalSigningCertificateScriptExists() {
        XCTAssertTrue(FileManager.default.fileExists(atPath: "scripts/create-local-signing-certificate.sh"))
    }
}
