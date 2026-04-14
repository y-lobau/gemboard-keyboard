import Foundation

enum PlynCompanionLaunchURL {
  private static let companionScheme = "plyn"
  private static let sessionHost = "session"

  static func isCompanionURL(_ url: URL) -> Bool {
    url.scheme?.caseInsensitiveCompare(companionScheme) == .orderedSame
  }

  static func shouldRestoreSession(for url: URL) -> Bool {
    isCompanionURL(url) && url.host?.caseInsensitiveCompare(sessionHost) == .orderedSame
  }
}
