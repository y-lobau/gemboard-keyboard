import XCTest

final class PlyńKeyboardE2ETests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  func testDictationAddsTranscriptToDraft() throws {
    let app = XCUIApplication()
    app.launchEnvironment["Plyń_E2E"] = "1"
    app.launchEnvironment["Plyń_E2E_HAS_API_KEY"] = "1"
    app.launchEnvironment["Plyń_E2E_SESSION_ACTIVE"] = "1"
    app.launchEnvironment["Plyń_E2E_TRANSCRIPT"] = "Прывiтанне з e2e"
    app.launch()

    let micButton = app.descendants(matching: .any)["companion-mic-button"]
    XCTAssertTrue(waitForElementToAppear(micButton, in: app))
    micButton.press(forDuration: 0.5)

    let draftInput = app.descendants(matching: .any)["draft-input"]
    XCTAssertTrue(draftInput.waitForExistence(timeout: 5))

    let draftValue = draftInput.value as? String ?? ""
    XCTAssertTrue(draftValue.contains("Прывiтанне з e2e"), "Expected draft to contain transcript, got: \(draftValue)")
  }
  private func waitForElementToAppear(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
    if element.waitForExistence(timeout: 3) {
      return true
    }

    for _ in 0..<4 {
      app.swipeUp()
      if element.waitForExistence(timeout: 1) {
        return true
      }
    }

    return false
  }
}
