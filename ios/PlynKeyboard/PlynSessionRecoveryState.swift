import Foundation

enum PlynCompanionSessionDemandAction: String {
  case none
  case start
  case stop
}

enum PlynCompanionSessionDemand {
  static func actionForKeyboardVisibility(
    isKeyboardVisible: Bool,
    isAppBackgrounded: Bool,
    isSessionActive: Bool,
    hasAPIKey: Bool
  ) -> PlynCompanionSessionDemandAction {
    if isKeyboardVisible {
      return hasAPIKey && !isSessionActive ? .start : .none
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
