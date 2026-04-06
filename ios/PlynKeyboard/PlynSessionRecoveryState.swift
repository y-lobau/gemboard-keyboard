import Foundation

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
