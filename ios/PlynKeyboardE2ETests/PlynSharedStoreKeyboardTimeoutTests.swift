import XCTest

final class PlynSharedStoreKeyboardTimeoutTests: XCTestCase {
  private let commandTimeoutKey = "keyboard_command_timeout_seconds"
  private let transcriptionTimeoutKey = "keyboard_transcription_timeout_seconds"

  private var defaults: UserDefaults {
    UserDefaults(suiteName: PlynSharedStore.appGroupIdentifier) ?? .standard
  }

  override func setUp() {
    super.setUp()
    defaults.removeObject(forKey: commandTimeoutKey)
    defaults.removeObject(forKey: transcriptionTimeoutKey)
    defaults.synchronize()
  }

  override func tearDown() {
    defaults.removeObject(forKey: commandTimeoutKey)
    defaults.removeObject(forKey: transcriptionTimeoutKey)
    defaults.synchronize()
    super.tearDown()
  }

  func testKeyboardTimeoutsUseBundledDefaultsWhenNoOverrideIsSaved() {
    XCTAssertEqual(2.0, PlynSharedStore.keyboardCommandTimeout())
    XCTAssertEqual(12.0, PlynSharedStore.keyboardTranscriptionTimeout())
  }

  func testKeyboardTimeoutsReadSavedRuntimeConfigOverrides() {
    PlynSharedStore.saveKeyboardCommandTimeout(3.5)
    PlynSharedStore.saveKeyboardTranscriptionTimeout(24)

    XCTAssertEqual(3.5, PlynSharedStore.keyboardCommandTimeout())
    XCTAssertEqual(24, PlynSharedStore.keyboardTranscriptionTimeout())
  }
}
