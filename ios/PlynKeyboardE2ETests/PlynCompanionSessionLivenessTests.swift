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

  func testTreatsActiveSessionWithStaleHeartbeatAsUnavailable() {
    let staleHeartbeat = Date(timeIntervalSinceNow: -30)

    XCTAssertFalse(
      PlynCompanionSessionLiveness.isResponsive(
        isSessionActive: true,
        heartbeatTimestamp: staleHeartbeat
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
