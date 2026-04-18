import XCTest

final class PlynCompanionSessionLivenessTests: XCTestCase {
  func testTreatsActiveSessionAsResponsiveBeforeFirstHeartbeatArrives() {
    XCTAssertTrue(
      PlynCompanionSessionLiveness.isResponsive(
        isSessionActive: true,
        heartbeatTimestamp: nil
      )
    )
  }

  func testTreatsActiveSessionWithFreshHeartbeatAsResponsive() {
    let freshHeartbeat = Date(timeIntervalSinceNow: -1)

    XCTAssertTrue(
      PlynCompanionSessionLiveness.isResponsive(
        isSessionActive: true,
        heartbeatTimestamp: freshHeartbeat
      )
    )
  }

  func testTreatsActiveSessionWithStaleHeartbeatAsUnavailable() {
    let staleHeartbeat = Date(timeIntervalSinceNow: -30)

    XCTAssertFalse(
      PlynCompanionSessionLiveness.isResponsive(
        isSessionActive: true,
        heartbeatTimestamp: staleHeartbeat
      )
    )
  }

  func testTreatsRecoveryAttemptAsResponsiveWhileWaitingForFreshHeartbeat() {
    let recoveryAttempt = Date(timeIntervalSinceNow: -2)

    XCTAssertTrue(
      PlynCompanionSessionLiveness.isResponsive(
        isSessionActive: false,
        heartbeatTimestamp: nil,
        recoveryAttemptTimestamp: recoveryAttempt
      )
    )
  }

  func testTreatsRequestedActiveCompanionWithFreshPresenceHeartbeatAsRecoverable() {
    let freshPresenceHeartbeat = Date(timeIntervalSinceNow: -1)

    XCTAssertTrue(
      PlynCompanionSessionLiveness.isRecoverable(
        isSessionRequestedActive: true,
        requestedHeartbeatTimestamp: freshPresenceHeartbeat
      )
    )
  }

  func testDoesNotTreatRequestedActiveCompanionAsRecoverableAfterPresenceHeartbeatExpires() {
    let stalePresenceHeartbeat = Date(timeIntervalSinceNow: -30)

    XCTAssertFalse(
      PlynCompanionSessionLiveness.isRecoverable(
        isSessionRequestedActive: true,
        requestedHeartbeatTimestamp: stalePresenceHeartbeat
      )
    )
  }

  func testTreatsRecentRecoveryLaunchAsRecoverableWhileWaitingForPresenceHeartbeat() {
    let recoveryAttempt = Date(timeIntervalSinceNow: -2)

    XCTAssertTrue(
      PlynCompanionSessionLiveness.isRecoverable(
        isSessionRequestedActive: false,
        requestedHeartbeatTimestamp: nil,
        recoveryAttemptTimestamp: recoveryAttempt
      )
    )
  }

  func testDoesNotTreatInactiveCompanionAsRecoverableWithoutPresenceOrRecoveryGrace() {
    XCTAssertFalse(
      PlynCompanionSessionLiveness.isRecoverable(
        isSessionRequestedActive: false,
        requestedHeartbeatTimestamp: nil,
        recoveryAttemptTimestamp: nil
      )
    )
  }

  func testTreatsExpiredRecoveryAttemptAsUnavailable() {
    let expiredRecoveryAttempt = Date(timeIntervalSinceNow: -30)

    XCTAssertFalse(
      PlynCompanionSessionLiveness.isResponsive(
        isSessionActive: false,
        heartbeatTimestamp: nil,
        recoveryAttemptTimestamp: expiredRecoveryAttempt
      )
    )
  }

  func testTreatsInactiveSessionAsUnavailableEvenWithFreshHeartbeat() {
    let freshHeartbeat = Date(timeIntervalSinceNow: -1)

    XCTAssertFalse(
      PlynCompanionSessionLiveness.isResponsive(
        isSessionActive: false,
        heartbeatTimestamp: freshHeartbeat
      )
    )
  }

  func testTreatsInactiveSessionWithoutHeartbeatAsUnavailable() {
    XCTAssertFalse(
      PlynCompanionSessionLiveness.isResponsive(
        isSessionActive: false,
        heartbeatTimestamp: nil
      )
    )
  }
}
