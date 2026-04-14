import Foundation

enum PlynCompanionSessionDemandAction: String {
  case none
  case start
  case stop
}

enum PlynCompanionSessionActivationSource: String {
  case automatic
  case manual
}

enum PlynCompanionSessionDemand {
  struct Context: Equatable {
    let isKeyboardVisible: Bool
    let isAppBackgrounded: Bool
    let isSessionActive: Bool
    let hasAPIKey: Bool
    let activationSource: PlynCompanionSessionActivationSource?
  }

  static func shouldReevaluate(
    previousContext: Context?,
    currentContext: Context,
    forceEvaluation: Bool = false
  ) -> Bool {
    guard !forceEvaluation else {
      return true
    }

    return previousContext != currentContext
  }

  static func actionForKeyboardVisibility(
    isKeyboardVisible: Bool,
    isAppBackgrounded: Bool,
    isSessionActive: Bool,
    hasAPIKey: Bool,
    activationSource: PlynCompanionSessionActivationSource? = nil,
    recoveryAttemptTimestamp: Date? = nil,
    now: Date = Date()
  ) -> PlynCompanionSessionDemandAction {
    if isKeyboardVisible {
      return isAppBackgrounded && hasAPIKey && !isSessionActive ? .start : .none
    }

    if !isAppBackgrounded, isSessionActive {
      return activationSource == .automatic ? .stop : .none
    }

    return .none
  }
}

struct PlynSessionRecoveryState {
  private(set) var shouldKeepSessionActive = false
  private(set) var isSuspendedForAppRecording = false
  private(set) var activationSource: PlynCompanionSessionActivationSource?

  mutating func markSessionRequestedActive(source: PlynCompanionSessionActivationSource = .automatic) {
    shouldKeepSessionActive = true
    activationSource = source
  }

  mutating func markSessionStopped() {
    shouldKeepSessionActive = false
    isSuspendedForAppRecording = false
    activationSource = nil
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
