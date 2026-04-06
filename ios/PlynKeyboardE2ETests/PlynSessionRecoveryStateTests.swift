import XCTest

final class PlynSessionRecoveryStateTests: XCTestCase {
  func testRecoversWhenSessionShouldStayActiveAndEngineStopped() {
    var state = PlynSessionRecoveryState()

    state.markSessionRequestedActive()

    XCTAssertTrue(state.shouldAttemptRecovery(engineRunning: false))
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
}
