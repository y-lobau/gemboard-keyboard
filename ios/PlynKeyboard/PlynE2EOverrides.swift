import Foundation

enum PlyńE2EOverrides {
  private static var sessionActiveState: Bool?

  static var isEnabled: Bool {
    ProcessInfo.processInfo.environment["Plyń_E2E"] == "1"
  }

  static var hasApiKey: Bool? {
    boolValue(for: "Plyń_E2E_HAS_API_KEY")
  }

  static var initialSessionActive: Bool? {
    boolValue(for: "Plyń_E2E_SESSION_ACTIVE")
  }

  static var transcript: String? {
    guard isEnabled else {
      return nil
    }

    return ProcessInfo.processInfo.environment["Plyń_E2E_TRANSCRIPT"]
  }

  static var transcriptError: String? {
    guard isEnabled else {
      return nil
    }

    return ProcessInfo.processInfo.environment["Plyń_E2E_TRANSCRIPT_ERROR"]
  }

  static func currentSessionActive(fallback: Bool) -> Bool {
    if let sessionActiveState {
      return sessionActiveState
    }

    if let initialSessionActive {
      sessionActiveState = initialSessionActive
      return initialSessionActive
    }

    sessionActiveState = fallback
    return fallback
  }

  static func setSessionActive(_ isActive: Bool) {
    guard isEnabled else {
      return
    }

    sessionActiveState = isActive
  }

  private static func boolValue(for key: String) -> Bool? {
    guard isEnabled else {
      return nil
    }

    guard let rawValue = ProcessInfo.processInfo.environment[key]?.lowercased() else {
      return nil
    }

    switch rawValue {
    case "1", "true", "yes":
      return true
    case "0", "false", "no":
      return false
    default:
      return nil
    }
  }
}
