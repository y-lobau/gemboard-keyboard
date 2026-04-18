import XCTest

final class PlynSessionManagerTests: XCTestCase {
  func testReportsSharedSessionActiveWhenAudioEngineIsRunning() {
    XCTAssertTrue(
      PlynCompanionSessionAvailability.isSharedSessionActive(
        engineRunning: true,
        suspendedForAppRecording: false
      )
    )
  }

  func testReportsSharedSessionActiveWhenHostAppTemporarilyOwnsRecording() {
    XCTAssertTrue(
      PlynCompanionSessionAvailability.isSharedSessionActive(
        engineRunning: false,
        suspendedForAppRecording: true
      )
    )
  }

  func testDoesNotReportSharedSessionActiveWhileRecoveryIsOnlyPending() {
    XCTAssertFalse(
      PlynCompanionSessionAvailability.isSharedSessionActive(
        engineRunning: false,
        suspendedForAppRecording: false
      )
    )
  }

  func testReportsSharedSessionRequestedActiveWhileRecoveryIsPending() {
    XCTAssertTrue(
      PlynCompanionSessionAvailability.isSharedSessionRequestedActive(
        shouldKeepSessionActive: true,
        engineRunning: false,
        suspendedForAppRecording: false
      )
    )
  }

  func testDoesNotReportSharedSessionRequestedActiveAfterExplicitStop() {
    XCTAssertFalse(
      PlynCompanionSessionAvailability.isSharedSessionRequestedActive(
        shouldKeepSessionActive: false,
        engineRunning: false,
        suspendedForAppRecording: false
      )
    )
  }

  func testStartsRecoveryGraceOnlyAfterAcceptedSessionRecoveryLaunch() {
    XCTAssertTrue(
      PlynCompanionRecoveryLaunch.shouldPersistRecoveryAttemptTimestamp(
        requestedURL: URL(string: "plyn://session"),
        didLaunchSucceed: true
      )
    )
  }

  func testDoesNotStartRecoveryGraceForFailedSessionRecoveryLaunch() {
    XCTAssertFalse(
      PlynCompanionRecoveryLaunch.shouldPersistRecoveryAttemptTimestamp(
        requestedURL: URL(string: "plyn://session"),
        didLaunchSucceed: false
      )
    )
  }

  func testDoesNotStartRecoveryGraceForNonRecoveryLaunch() {
    XCTAssertFalse(
      PlynCompanionRecoveryLaunch.shouldPersistRecoveryAttemptTimestamp(
        requestedURL: URL(string: "plyn://"),
        didLaunchSucceed: true
      )
    )
  }

  func testAcceptsValidAudioInputFormat() {
    XCTAssertTrue(PlynAudioInputFormat.isValidRecordingFormat(sampleRate: 16_000, channelCount: 1))
    XCTAssertTrue(PlynAudioInputFormat.isValidRecordingFormat(sampleRate: 44_100, channelCount: 2))
  }

  func testRejectsInvalidAudioInputFormat() {
    XCTAssertFalse(PlynAudioInputFormat.isValidRecordingFormat(sampleRate: 0, channelCount: 1))
    XCTAssertFalse(PlynAudioInputFormat.isValidRecordingFormat(sampleRate: 16_000, channelCount: 0))
    XCTAssertFalse(PlynAudioInputFormat.isValidRecordingFormat(sampleRate: -1, channelCount: 1))
  }
}
