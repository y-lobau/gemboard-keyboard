import XCTest

final class PlynSessionRecoveryStateTests: XCTestCase {
  func testRecoversWhenSessionShouldStayActiveAndEngineStopped() {
    var state = PlynSessionRecoveryState()

    state.markSessionRequestedActive()

    XCTAssertTrue(state.shouldAttemptRecovery(engineRunning: false))
  }

  func testKeepsRequestedSessionActiveWhileRecoveryIsStillPending() {
    var state = PlynSessionRecoveryState()

    state.markSessionRequestedActive()

    XCTAssertTrue(state.shouldKeepSessionActive)
  }

  func testDoesNotRecoverAfterExplicitStop() {
    var state = PlynSessionRecoveryState()

    state.markSessionRequestedActive()
    state.markSessionStopped()

    XCTAssertFalse(state.shouldAttemptRecovery(engineRunning: false))
  }

  func testDoesNotRecoverWhileSuspendedForHostAppRecording() {
    var state = PlynSessionRecoveryState()

    state.markSessionRequestedActive()
    state.markSuspendedForAppRecording()

    XCTAssertFalse(state.shouldAttemptRecovery(engineRunning: false))
  }

  func testRecoversAgainAfterHostAppRecordingFinishes() {
    var state = PlynSessionRecoveryState()

    state.markSessionRequestedActive()
    state.markSuspendedForAppRecording()
    state.markResumedAfterAppRecording()

    XCTAssertTrue(state.shouldAttemptRecovery(engineRunning: false))
  }

  func testDoesNotRecoverWhenEngineAlreadyRuns() {
    var state = PlynSessionRecoveryState()

    state.markSessionRequestedActive()

    XCTAssertFalse(state.shouldAttemptRecovery(engineRunning: true))
  }

  func testKeepsRecoveryIntentUntilSessionStopsExplicitly() {
    var state = PlynSessionRecoveryState()

    state.markSessionRequestedActive()

    XCTAssertTrue(state.shouldAttemptRecovery(engineRunning: false))

    state.markSessionStopped()

    XCTAssertFalse(state.shouldAttemptRecovery(engineRunning: false))
  }

  func testDoesNotKeepRequestedSessionActiveAfterExplicitStop() {
    var state = PlynSessionRecoveryState()

    state.markSessionRequestedActive()
    state.markSessionStopped()

    XCTAssertFalse(state.shouldKeepSessionActive)
  }

  func testKeepsRequestedSessionActiveDuringAudioInterruption() {
    var state = PlynSessionRecoveryState()

    state.markSessionRequestedActive()
    state.markAudioSessionInterrupted()

    XCTAssertTrue(state.shouldKeepSessionActive)
    XCTAssertTrue(state.shouldAttemptRecovery(engineRunning: false))
  }
}
