import XCTest

final class PlynSessionRecoveryStateTests: XCTestCase {
  func testRecoversWhenSessionShouldStayActiveAndEngineStopped() {
    var state = PlynSessionRecoveryState()

    state.markSessionRequestedActive(source: .automatic)

    XCTAssertTrue(state.shouldAttemptRecovery(engineRunning: false))
  }

  func testDoesNotRecoverAfterExplicitStop() {
    var state = PlynSessionRecoveryState()

    state.markSessionRequestedActive(source: .automatic)
    state.markSessionStopped()

    XCTAssertFalse(state.shouldAttemptRecovery(engineRunning: false))
  }

  func testDoesNotRecoverWhileSuspendedForHostAppRecording() {
    var state = PlynSessionRecoveryState()

    state.markSessionRequestedActive(source: .automatic)
    state.markSuspendedForAppRecording()

    XCTAssertFalse(state.shouldAttemptRecovery(engineRunning: false))
  }

  func testRecoversAgainAfterHostAppRecordingFinishes() {
    var state = PlynSessionRecoveryState()

    state.markSessionRequestedActive(source: .automatic)
    state.markSuspendedForAppRecording()
    state.markResumedAfterAppRecording()

    XCTAssertTrue(state.shouldAttemptRecovery(engineRunning: false))
  }

  func testDoesNotRecoverWhenEngineAlreadyRuns() {
    var state = PlynSessionRecoveryState()

    state.markSessionRequestedActive(source: .automatic)

    XCTAssertFalse(state.shouldAttemptRecovery(engineRunning: true))
  }

  func testTracksManualActivationSourceWhileSessionShouldStayActive() {
    var state = PlynSessionRecoveryState()

    state.markSessionRequestedActive(source: .manual)

    XCTAssertEqual(state.activationSource, .manual)
  }

  func testClearsActivationSourceAfterExplicitStop() {
    var state = PlynSessionRecoveryState()

    state.markSessionRequestedActive(source: .manual)
    state.markSessionStopped()

    XCTAssertNil(state.activationSource)
  }
}
