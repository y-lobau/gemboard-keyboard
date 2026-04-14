import XCTest

final class PlynSharedStoreDefaultsSuiteTests: XCTestCase {
  override func tearDown() {
    let sharedDefaults = UserDefaults(suiteName: PlynSharedStore.sharedDefaultsIdentifier)
    sharedDefaults?.removePersistentDomain(forName: PlynSharedStore.sharedDefaultsIdentifier)
    UserDefaults.standard.removeObject(forKey: "gemini_api_key")
    UserDefaults.standard.removeObject(forKey: "gemini_runtime_model")
    UserDefaults.standard.removeObject(forKey: "gemini_runtime_system_prompt")
    UserDefaults.standard.synchronize()
    unsetenv(PlynSharedStore.simulatorPersistentDefaultsOverrideEnvironmentKey)
    super.tearDown()
  }

  func testUsesSimulatorSharedDefaultsSuiteForValidationBuilds() {
    XCTAssertEqual(
      PlynSharedStore.sharedDefaultsIdentifier,
      PlynSharedStore.simulatorSharedDefaultsIdentifier
    )
  }

  func testMigratesExistingStandardDefaultsIntoSimulatorSharedSuite() {
    let sharedDefaults = UserDefaults(suiteName: PlynSharedStore.sharedDefaultsIdentifier)
    let apiKey = "simulator-migration-key"

    sharedDefaults?.removePersistentDomain(forName: PlynSharedStore.sharedDefaultsIdentifier)
    UserDefaults.standard.removeObject(forKey: "gemini_api_key")
    UserDefaults.standard.set(apiKey, forKey: "gemini_api_key")
    UserDefaults.standard.synchronize()

    XCTAssertEqual(PlynSharedStore.apiKey(), apiKey)
    XCTAssertEqual(sharedDefaults?.string(forKey: "gemini_api_key"), apiKey)
  }

  func testRestoresSavedApiKeyAfterSimulatorSuiteIsReset() throws {
    let overrideRootURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: overrideRootURL, withIntermediateDirectories: true)
    setenv(
      PlynSharedStore.simulatorPersistentDefaultsOverrideEnvironmentKey,
      overrideRootURL.path,
      1
    )

    let sharedDefaults = UserDefaults(suiteName: PlynSharedStore.sharedDefaultsIdentifier)
    sharedDefaults?.removePersistentDomain(forName: PlynSharedStore.sharedDefaultsIdentifier)
    UserDefaults.standard.removeObject(forKey: "gemini_api_key")

    PlynSharedStore.saveApiKey("simulator-reinstall-key")
    sharedDefaults?.removePersistentDomain(forName: PlynSharedStore.sharedDefaultsIdentifier)

    XCTAssertEqual(PlynSharedStore.apiKey(), "simulator-reinstall-key")
    XCTAssertEqual(sharedDefaults?.string(forKey: "gemini_api_key"), "simulator-reinstall-key")

    let persistedValues = NSDictionary(contentsOf: PlynSharedStore.simulatorPersistentDefaultsURL)
    XCTAssertEqual(persistedValues?["gemini_api_key"] as? String, "simulator-reinstall-key")
  }

  func testSynchronizesSimulatorSharedStateAcrossContainers() throws {
    let overrideRootURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: overrideRootURL, withIntermediateDirectories: true)
    setenv(
      PlynSharedStore.simulatorPersistentDefaultsOverrideEnvironmentKey,
      overrideRootURL.path,
      1
    )

    let sharedDefaults = UserDefaults(suiteName: PlynSharedStore.sharedDefaultsIdentifier)
    sharedDefaults?.removePersistentDomain(forName: PlynSharedStore.sharedDefaultsIdentifier)
    sharedDefaults?.set(false, forKey: "ios_session_active")
    sharedDefaults?.set("inactive", forKey: "ios_keyboard_status")
    sharedDefaults?.synchronize()

    let persistedValues: NSDictionary = [
      "gemini_api_key": "cross-container-key",
      "ios_session_active": true,
      "ios_session_validation_only": true,
      "ios_keyboard_status": "ready",
      "ios_session_heartbeat_updated_at": 1234.0,
    ]
    persistedValues.write(to: PlynSharedStore.simulatorPersistentDefaultsURL, atomically: true)

    XCTAssertTrue(PlynSharedStore.hasApiKey())
    XCTAssertTrue(PlynSharedStore.isSessionActive())
    XCTAssertTrue(PlynSharedStore.isValidationOnlySession())
    XCTAssertEqual(PlynSharedStore.keyboardStatus(), .ready)
    XCTAssertEqual(sharedDefaults?.string(forKey: "gemini_api_key"), "cross-container-key")
    XCTAssertEqual(sharedDefaults?.bool(forKey: "ios_session_active"), true)
    XCTAssertEqual(sharedDefaults?.bool(forKey: "ios_session_validation_only"), true)
    XCTAssertEqual(sharedDefaults?.string(forKey: "ios_keyboard_status"), "ready")
  }

  func testSavingActiveSessionDoesNotClearValidationOnlyFlag() throws {
    let overrideRootURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: overrideRootURL, withIntermediateDirectories: true)
    setenv(
      PlynSharedStore.simulatorPersistentDefaultsOverrideEnvironmentKey,
      overrideRootURL.path,
      1
    )

    let sharedDefaults = UserDefaults(suiteName: PlynSharedStore.sharedDefaultsIdentifier)
    sharedDefaults?.removePersistentDomain(forName: PlynSharedStore.sharedDefaultsIdentifier)

    PlynSharedStore.saveValidationOnlySession(true)
    PlynSharedStore.saveSessionActive(true)

    XCTAssertTrue(PlynSharedStore.isSessionActive())
    XCTAssertTrue(PlynSharedStore.isValidationOnlySession())

    let persistedValues = NSDictionary(contentsOf: PlynSharedStore.simulatorPersistentDefaultsURL)
    XCTAssertEqual(persistedValues?["ios_session_validation_only"] as? Bool, true)
  }

  func testResolvesSimulatorPersistentDefaultsURLForPluginKitContainer() {
    let homePath = "/Users/test/Library/Developer/CoreSimulator/Devices/device-id/data/Containers/Data/PluginKitPlugin/plugin-id"

    XCTAssertEqual(
      PlynSharedStore.simulatorPersistentDefaultsURL(homePath: homePath)?.path,
      "/Users/test/Library/Developer/CoreSimulator/Devices/device-id/data/Library/Preferences/simulator.group.com.holas.plynkeyboard.persisted.plist"
    )
  }
}
