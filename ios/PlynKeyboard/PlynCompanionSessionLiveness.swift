import Foundation

enum PlynCompanionRecoveryLaunch {
  private static let sessionRecoveryURL = URL(string: "plyn://session")

  static func shouldPersistRecoveryAttemptTimestamp(
    requestedURL: URL?,
    didLaunchSucceed: Bool
  ) -> Bool {
    didLaunchSucceed && requestedURL == sessionRecoveryURL
  }
}

enum PlynCompanionSessionLiveness {
  static let handoffWindow: TimeInterval = 5.0
  static let recoveryAttemptWindow: TimeInterval = 6.0

  static func isResponsive(
    isSessionActive: Bool,
    heartbeatTimestamp: Date?,
    recoveryAttemptTimestamp: Date? = nil,
    now: Date = Date()
  ) -> Bool {
    if isSessionActive {
      guard let heartbeatTimestamp else {
        return true
      }

      if now.timeIntervalSince(heartbeatTimestamp) <= handoffWindow {
        return true
      }
    }

    guard let recoveryAttemptTimestamp else {
      return false
    }

    let recoveryAge = now.timeIntervalSince(recoveryAttemptTimestamp)
    return recoveryAge >= 0 && recoveryAge <= recoveryAttemptWindow
  }

  static func isRecoverable(
    isSessionRequestedActive: Bool,
    requestedHeartbeatTimestamp: Date?,
    recoveryAttemptTimestamp: Date? = nil,
    now: Date = Date()
  ) -> Bool {
    if isSessionRequestedActive {
      guard let requestedHeartbeatTimestamp else {
        return true
      }

      if now.timeIntervalSince(requestedHeartbeatTimestamp) <= handoffWindow {
        return true
      }
    }

    guard let recoveryAttemptTimestamp else {
      return false
    }

    let recoveryAge = now.timeIntervalSince(recoveryAttemptTimestamp)
    return recoveryAge >= 0 && recoveryAge <= recoveryAttemptWindow
  }
}
