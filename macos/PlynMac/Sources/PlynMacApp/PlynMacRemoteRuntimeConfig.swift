import FirebaseCore
import FirebaseRemoteConfig
import Foundation
import PlynMacCore

enum PlynMacRemoteRuntimeConfig {
  private static let systemPromptKey = "gemini_system_prompt"

  static func configureFirebaseIfNeeded() {
    guard FirebaseApp.app() == nil else {
      return
    }

    if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
       let options = FirebaseOptions(contentsOfFile: path)
    {
      FirebaseApp.configure(options: options)
      PlynMacLogger.log("firebase configured from GoogleService-Info.plist")
    } else {
      PlynMacLogger.log("firebase config missing GoogleService-Info.plist")
    }
  }

  static func refresh(preferences: PlynMacPreferences) {
    configureFirebaseIfNeeded()
    guard FirebaseApp.app() != nil else {
      return
    }

    let remoteConfig = RemoteConfig.remoteConfig()
    let settings = RemoteConfigSettings()
    settings.minimumFetchInterval = 0
    settings.fetchTimeout = 10
    remoteConfig.configSettings = settings

    remoteConfig.fetchAndActivate { _, error in
      if let error {
        PlynMacLogger.log("remote config fetch failed error=\(error.localizedDescription)")
        return
      }

      let systemPrompt = remoteConfig.configValue(forKey: systemPromptKey).stringValue
        .trimmingCharacters(in: .whitespacesAndNewlines)

      preferences.saveGeminiSystemPrompt(systemPrompt)
      PlynMacLogger.log("remote config refreshed promptPresent=\(!systemPrompt.isEmpty)")
    }
  }
}
