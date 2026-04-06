import FirebaseRemoteConfig
import Foundation

enum PlyńRemoteRuntimeConfig {
  private static let modelKey = "gemini_model"
  private static let systemPromptKey = "gemini_system_prompt"
  private static let keyboardCommandTimeoutKey = "keyboard_command_timeout_seconds"
  private static let keyboardTranscriptionTimeoutKey = "keyboard_transcription_timeout_seconds"

  static func refreshForDictationSession() {
    let remoteConfig = RemoteConfig.remoteConfig()
    let settings = RemoteConfigSettings()
    settings.minimumFetchInterval = 0
    settings.fetchTimeout = 10
    remoteConfig.configSettings = settings

    remoteConfig.fetchAndActivate { _, error in
      guard error == nil else {
        return
      }

      let model = remoteConfig.configValue(forKey: modelKey).stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
      let systemPrompt = remoteConfig.configValue(forKey: systemPromptKey).stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
      let keyboardCommandTimeout = positiveTimeout(
        remoteConfig.configValue(forKey: keyboardCommandTimeoutKey).stringValue
      )
      let keyboardTranscriptionTimeout = positiveTimeout(
        remoteConfig.configValue(forKey: keyboardTranscriptionTimeoutKey).stringValue
      )

      guard !model.isEmpty, !systemPrompt.isEmpty else {
        return
      }

      PlynSharedStore.saveGeminiModel(model)
      PlynSharedStore.saveGeminiSystemPrompt(systemPrompt)
      if let keyboardCommandTimeout {
        PlynSharedStore.saveKeyboardCommandTimeout(keyboardCommandTimeout)
      }
      if let keyboardTranscriptionTimeout {
        PlynSharedStore.saveKeyboardTranscriptionTimeout(keyboardTranscriptionTimeout)
      }
    }
  }

  private static func positiveTimeout(_ rawValue: String?) -> TimeInterval? {
    let trimmedValue = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    guard let value = TimeInterval(trimmedValue), value.isFinite, value > .zero else {
      return nil
    }

    return value
  }
}
