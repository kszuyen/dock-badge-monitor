import XCTest
@testable import BadgeBell

final class PreferencesStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "PreferencesStoreTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testDefaults() {
        let store = PreferencesStore(defaults: defaults)

        XCTAssertTrue(store.isProviderEnabled("cyberlink-u"))
        XCTAssertEqual(store.pollingInterval, 2.0)
        XCTAssertEqual(store.alertPosition, .topRight)
        XCTAssertFalse(store.launchAtLogin)
        XCTAssertFalse(store.alertsPaused)
    }

    func testPersistence() {
        var store = PreferencesStore(defaults: defaults)

        store.setProviderEnabled(false, providerID: "cyberlink-u")
        store.pollingInterval = 5.0
        store.alertPosition = .topBar
        store.launchAtLogin = true
        store.alertsPaused = true

        let persistedStore = PreferencesStore(defaults: defaults)
        XCTAssertFalse(persistedStore.isProviderEnabled("cyberlink-u"))
        XCTAssertEqual(persistedStore.pollingInterval, 5.0)
        XCTAssertEqual(persistedStore.alertPosition, .topBar)
        XCTAssertTrue(persistedStore.launchAtLogin)
        XCTAssertTrue(persistedStore.alertsPaused)
    }
}
