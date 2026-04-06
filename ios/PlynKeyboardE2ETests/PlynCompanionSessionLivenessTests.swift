import XCTest

final class PlynCompanionSessionLivenessTests: XCTestCase {
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
