import Foundation

enum PlynKeyboardMicPressDecision {
  case allowCapture
  case blockForValidationOnlySession
  case captureWithExistingSession
  case finishCaptureWithExistingSession
  case cancelCapture
  case reopenCompanionApp

  static func forValidationOnlySession(isValidationOnly: Bool) -> PlynKeyboardMicPressDecision {
    isValidationOnly ? .blockForValidationOnlySession : .allowCapture
  }

  static func forUnavailableResponsiveSession(isSessionActive: Bool) -> PlynKeyboardMicPressDecision {
    isSessionActive ? .captureWithExistingSession : .reopenCompanionApp
  }

  static func forUnavailableResponsiveRelease(isSessionActive: Bool) -> PlynKeyboardMicPressDecision {
    isSessionActive ? .finishCaptureWithExistingSession : .cancelCapture
  }
}
