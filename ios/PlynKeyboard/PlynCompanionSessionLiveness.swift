import Foundation

enum PlynCompanionSessionLiveness {
  static let handoffWindow: TimeInterval = 5.0
  static let recoveryAttemptWindow: TimeInterval = 6.0

  static func isResponsive(
    isSessionActive: Bool,
    heartbeatTimestamp: Date?,
    recoveryAttemptTimestamp: Date? = nil,
    now: Date = Date()
  ) -> Bool {
    if isSessionActive,
       let heartbeatTimestamp,
       now.timeIntervalSince(heartbeatTimestamp) <= handoffWindow
    {
      return true
    }

    guard let recoveryAttemptTimestamp else {
      return false
    }

    let recoveryAge = now.timeIntervalSince(recoveryAttemptTimestamp)
    return recoveryAge >= 0 && recoveryAge <= recoveryAttemptWindow
  }
}
