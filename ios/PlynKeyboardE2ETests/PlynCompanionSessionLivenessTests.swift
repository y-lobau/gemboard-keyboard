import XCTest

final class PlynCompanionSessionLivenessTests: XCTestCase {
  func testReevaluatesDemandWhenSessionActivityChangesWhileKeyboardStaysVisible() {
    let previousContext = PlynCompanionSessionDemand.Context(
      isKeyboardVisible: true,
      isAppBackgrounded: true,
      isSessionActive: true,
      hasAPIKey: true,
      activationSource: .automatic
    )
    let currentContext = PlynCompanionSessionDemand.Context(
      isKeyboardVisible: true,
      isAppBackgrounded: true,
      isSessionActive: false,
      hasAPIKey: true,
      activationSource: .automatic
    )

    XCTAssertTrue(
      PlynCompanionSessionDemand.shouldReevaluate(
        previousContext: previousContext,
        currentContext: currentContext
      )
    )
  }

  func testDoesNotReevaluateDemandWhenInputsAreUnchangedWithoutForce() {
    let context = PlynCompanionSessionDemand.Context(
      isKeyboardVisible: true,
      isAppBackgrounded: true,
      isSessionActive: false,
      hasAPIKey: true,
      activationSource: .automatic
    )

    XCTAssertFalse(
      PlynCompanionSessionDemand.shouldReevaluate(
        previousContext: context,
        currentContext: context
      )
    )
  }

  func testRequestsSessionStartWhenKeyboardBecomesVisibleAndSessionIsInactive() {
    XCTAssertEqual(
      PlynCompanionSessionDemand.actionForKeyboardVisibility(
        isKeyboardVisible: true,
        isAppBackgrounded: true,
        isSessionActive: false,
        hasAPIKey: true,
        activationSource: nil
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
        hasAPIKey: false,
        activationSource: nil
      ),
      .none
    )
  }

  func testDoesNotRequestSessionStartWhileCompanionAppIsForegroundedEvenIfKeyboardIsVisible() {
    XCTAssertEqual(
      PlynCompanionSessionDemand.actionForKeyboardVisibility(
        isKeyboardVisible: true,
        isAppBackgrounded: false,
        isSessionActive: false,
        hasAPIKey: true,
        activationSource: nil
      ),
      .none
    )
  }

  func testKeepsSessionRunningWhenKeyboardHidesWhileAppIsBackgrounded() {
    XCTAssertEqual(
      PlynCompanionSessionDemand.actionForKeyboardVisibility(
        isKeyboardVisible: false,
        isAppBackgrounded: true,
        isSessionActive: true,
        hasAPIKey: true,
        activationSource: .automatic
      ),
      .none
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
        activationSource: .automatic,
        recoveryAttemptTimestamp: recoveryAttemptTimestamp,
        now: now
      ),
      .none
    )
  }

  func testStopsAutomaticKeyboardDrivenSessionWhenCompanionAppReturnsToForeground() {
    XCTAssertEqual(
      PlynCompanionSessionDemand.actionForKeyboardVisibility(
        isKeyboardVisible: false,
        isAppBackgrounded: false,
        isSessionActive: true,
        hasAPIKey: true,
        activationSource: .automatic
      ),
      .stop
    )
  }

  func testKeepsManualForegroundSessionRunningWhenStartedFromCompanionApp() {
    XCTAssertEqual(
      PlynCompanionSessionDemand.actionForKeyboardVisibility(
        isKeyboardVisible: false,
        isAppBackgrounded: false,
        isSessionActive: true,
        hasAPIKey: true,
        activationSource: .manual
      ),
      .none
    )
  }

  func testDoesNotStopWhenForegroundAppAlreadyHasNoActiveSession() {
    XCTAssertEqual(
      PlynCompanionSessionDemand.actionForKeyboardVisibility(
        isKeyboardVisible: false,
        isAppBackgrounded: false,
        isSessionActive: false,
        hasAPIKey: true,
        activationSource: nil
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
