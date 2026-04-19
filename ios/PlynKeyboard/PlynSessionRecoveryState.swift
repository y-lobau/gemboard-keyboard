import Foundation

enum PlynCompanionSessionAvailability {
  static func isSharedSessionActive(
    engineRunning: Bool,
    suspendedForAppRecording: Bool
  ) -> Bool {
    suspendedForAppRecording || engineRunning
  }

  static func isSharedSessionRequestedActive(
    shouldKeepSessionActive: Bool,
    engineRunning: Bool,
    suspendedForAppRecording: Bool
  ) -> Bool {
    shouldKeepSessionActive || isSharedSessionActive(
      engineRunning: engineRunning,
      suspendedForAppRecording: suspendedForAppRecording
    )
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

  mutating func markAudioSessionInterrupted() {
    isSuspendedForAppRecording = false
  }

  mutating func markResumedAfterAppRecording() {
    isSuspendedForAppRecording = false
  }

  func shouldAttemptRecovery(engineRunning: Bool) -> Bool {
    shouldKeepSessionActive && !isSuspendedForAppRecording && !engineRunning
  }
}
