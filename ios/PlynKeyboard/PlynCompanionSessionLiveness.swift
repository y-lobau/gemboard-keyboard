import Foundation

enum PlynCompanionSessionLiveness {
  static let handoffWindow: TimeInterval = 5.0

  static func isResponsive(
    isSessionActive: Bool,
    heartbeatTimestamp: Date?,
    now: Date = Date()
  ) -> Bool {
    guard isSessionActive, let heartbeatTimestamp else {
      return false
    }

    return now.timeIntervalSince(heartbeatTimestamp) <= handoffWindow
  }
}
