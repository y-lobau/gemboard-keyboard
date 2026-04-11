import Foundation

enum PlynCompanionSessionDemandAction: String {
  case none
  case start
  case stop
}

enum PlynCompanionSessionDemand {
  private static let recoveryLaunchWindow: TimeInterval = 6.0

  static func actionForKeyboardVisibility(
    isKeyboardVisible: Bool,
    isAppBackgrounded: Bool,
    isSessionActive: Bool,
    hasAPIKey: Bool,
    recoveryAttemptTimestamp: Date? = nil,
    now: Date = Date()
  ) -> PlynCompanionSessionDemandAction {
    if isKeyboardVisible {
      return hasAPIKey && !isSessionActive ? .start : .none
    }

    if let recoveryAttemptTimestamp {
      let recoveryAge = now.timeIntervalSince(recoveryAttemptTimestamp)
      if recoveryAge >= 0 && recoveryAge <= recoveryLaunchWindow {
        return .none
      }
    }

    return isAppBackgrounded && isSessionActive ? .stop : .none
  }
}

struct PlynSessionRecoveryState {
  private(set) var shouldKeepSessionActive = false
  private(set) var isSuspendedForAppRecording = false

  mutating func markSessionRequestedActive() {
    shouldKeepSessionActive = true
  }

  mutating func markSessionStopped() {
    shouldKeepSessionActive = false
    isSuspendedForAppRecording = false
  }

  mutating func markSuspendedForAppRecording() {
    isSuspendedForAppRecording = true
  }

  mutating func markResumedAfterAppRecording() {
    isSuspendedForAppRecording = false
  }

  func shouldAttemptRecovery(engineRunning: Bool) -> Bool {
    shouldKeepSessionActive && !isSuspendedForAppRecording && !engineRunning
  }
}
