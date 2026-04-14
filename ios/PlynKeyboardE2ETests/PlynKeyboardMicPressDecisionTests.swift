import XCTest

final class PlynKeyboardMicPressDecisionTests: XCTestCase {
  func testBlocksCaptureInValidationOnlySession() {
    XCTAssertEqual(
      PlynKeyboardMicPressDecision.forValidationOnlySession(isValidationOnly: true),
      .blockForValidationOnlySession
    )
  }

  func testAllowsCaptureWhenSessionSupportsLiveDictation() {
    XCTAssertEqual(
      PlynKeyboardMicPressDecision.forValidationOnlySession(isValidationOnly: false),
      .allowCapture
    )
  }

  func testUsesExistingSessionWhenSharedStateStillMarksSessionActive() {
    XCTAssertEqual(
      PlynKeyboardMicPressDecision.forUnavailableResponsiveSession(isSessionActive: true),
      .captureWithExistingSession
    )
  }

  func testReopensCompanionAppWhenSessionIsInactive() {
    XCTAssertEqual(
      PlynKeyboardMicPressDecision.forUnavailableResponsiveSession(isSessionActive: false),
      .reopenCompanionApp
    )
  }

  func testReleaseStopsCaptureWhenSharedSessionRemainsActive() {
    XCTAssertEqual(
      PlynKeyboardMicPressDecision.forUnavailableResponsiveRelease(isSessionActive: true),
      .finishCaptureWithExistingSession
    )
  }

  func testReleaseCancelsCaptureWhenSharedSessionIsInactive() {
    XCTAssertEqual(
      PlynKeyboardMicPressDecision.forUnavailableResponsiveRelease(isSessionActive: false),
      .cancelCapture
    )
  }
}
