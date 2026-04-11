import XCTest

final class PlynCompanionSessionLivenessTests: XCTestCase {
  func testRequestsSessionStartWhenKeyboardBecomesVisibleAndSessionIsInactive() {
    XCTAssertEqual(
      PlynCompanionSessionDemand.actionForKeyboardVisibility(
        isKeyboardVisible: true,
        isAppBackgrounded: true,
        isSessionActive: false,
        hasAPIKey: true
      ),
      .start
    )
  }

  func testDoesNotRequestSessionStartWhenKeyboardBecomesVisibleWithoutApiKey() {
    XCTAssertEqual(
      PlynCompanionSessionDemand.actionForKeyboardVisibility(
        isKeyboardVisible: true,
        isAppBackgrounded: true,
        isSessionActive: false,
        hasAPIKey: false
      ),
      .none
    )
  }

  func testRequestsSessionStopWhenKeyboardHidesWhileAppIsBackgrounded() {
    XCTAssertEqual(
      PlynCompanionSessionDemand.actionForKeyboardVisibility(
        isKeyboardVisible: false,
        isAppBackgrounded: true,
        isSessionActive: true,
        hasAPIKey: true
      ),
      .stop
    )
  }

  func testKeepsSessionRunningDuringRecentRecoveryLaunchWhileKeyboardIsHidden() {
    let now = Date(timeIntervalSince1970: 1_000)
    let recoveryAttemptTimestamp = now.addingTimeInterval(-1)

    XCTAssertEqual(
      PlynCompanionSessionDemand.actionForKeyboardVisibility(
        isKeyboardVisible: false,
        isAppBackgrounded: true,
        isSessionActive: true,
        hasAPIKey: true,
        recoveryAttemptTimestamp: recoveryAttemptTimestamp,
        now: now
      ),
      .none
    )
  }

  func testKeepsSessionRunningWhenKeyboardHidesButCompanionAppIsForegrounded() {
    XCTAssertEqual(
      PlynCompanionSessionDemand.actionForKeyboardVisibility(
        isKeyboardVisible: false,
        isAppBackgrounded: false,
        isSessionActive: true,
        hasAPIKey: true
      ),
      .none
    )
  }

  func testTreatsRecentlyRefreshedHeartbeatAsResponsiveDuringRecoveryHandoff() {
    let now = Date(timeIntervalSince1970: 1_000)
    let heartbeatTimestamp = now.addingTimeInterval(-4)

    XCTAssertTrue(
      PlynCompanionSessionLiveness.isResponsive(
        isSessionActive: true,
        heartbeatTimestamp: heartbeatTimestamp,
        now: now
      )
    )
  }

  func testTreatsRecentRecoveryAttemptAsResponsiveWhileSessionIsStillStarting() {
    let now = Date(timeIntervalSince1970: 1_000)
    let recoveryAttemptTimestamp = now.addingTimeInterval(-1.5)

    XCTAssertTrue(
      PlynCompanionSessionLiveness.isResponsive(
        isSessionActive: false,
        heartbeatTimestamp: nil,
        recoveryAttemptTimestamp: recoveryAttemptTimestamp,
        now: now
      )
    )
  }

  func testTreatsRecoveryAttemptAsResponsiveForExtendedRecoveryWindow() {
    let now = Date(timeIntervalSince1970: 1_000)
    let recoveryAttemptTimestamp = now.addingTimeInterval(-(PlynCompanionSessionLiveness.recoveryAttemptWindow - 0.5))

    XCTAssertTrue(
      PlynCompanionSessionLiveness.isResponsive(
        isSessionActive: false,
        heartbeatTimestamp: nil,
        recoveryAttemptTimestamp: recoveryAttemptTimestamp,
        now: now
      )
    )
  }

  func testDoesNotTreatExpiredRecoveryAttemptAsResponsive() {
    let now = Date(timeIntervalSince1970: 1_000)
    let recoveryAttemptTimestamp = now.addingTimeInterval(-(PlynCompanionSessionLiveness.recoveryAttemptWindow + 0.5))

    XCTAssertFalse(
      PlynCompanionSessionLiveness.isResponsive(
        isSessionActive: false,
        heartbeatTimestamp: nil,
        recoveryAttemptTimestamp: recoveryAttemptTimestamp,
        now: now
      )
    )
  }

  func testTreatsExpiredHeartbeatAsInactiveAfterHandoffWindowPasses() {
    let now = Date(timeIntervalSince1970: 1_000)
    let heartbeatTimestamp = now.addingTimeInterval(-(PlynCompanionSessionLiveness.handoffWindow + 0.5))

    XCTAssertFalse(
      PlynCompanionSessionLiveness.isResponsive(
        isSessionActive: true,
        heartbeatTimestamp: heartbeatTimestamp,
        now: now
      )
    )
  }

  func testRequiresSharedSessionActiveFlag() {
    let now = Date(timeIntervalSince1970: 1_000)

    XCTAssertFalse(
      PlynCompanionSessionLiveness.isResponsive(
        isSessionActive: false,
        heartbeatTimestamp: now,
        now: now
      )
    )
  }

  func testRequiresHeartbeatTimestamp() {
    XCTAssertFalse(
      PlynCompanionSessionLiveness.isResponsive(
        isSessionActive: true,
        heartbeatTimestamp: nil,
        now: Date(timeIntervalSince1970: 1_000)
      )
    )
  }
}
