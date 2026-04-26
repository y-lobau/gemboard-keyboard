import Carbon
import Foundation

public struct PlynMacOutputLanguage: Equatable, Sendable {
  public let identifier: String
  public let displayName: String

  public static let belarusian = PlynMacOutputLanguage(identifier: "be", displayName: "Belarusian")

  public init(identifier: String, displayName: String) {
    self.identifier = identifier
    self.displayName = displayName
  }
}

public enum PlynMacInputLanguageResolver {
  public static func outputLanguage(for inputSourceLanguages: [String]) -> PlynMacOutputLanguage {
    guard let rawIdentifier = inputSourceLanguages.first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
      return .belarusian
    }

    let identifier = Locale(identifier: rawIdentifier).identifier
    let baseLanguage = Locale(identifier: identifier).language.languageCode?.identifier ?? identifier
    let displayName = Locale(identifier: "en").localizedString(forLanguageCode: baseLanguage) ?? baseLanguage

    guard !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return .belarusian
    }

    return PlynMacOutputLanguage(identifier: identifier, displayName: displayName)
  }
}

public protocol PlynMacInputLanguageDetecting: Sendable {
  func currentOutputLanguage() -> PlynMacOutputLanguage
}

public struct PlynMacInputSourceLanguageDetector: PlynMacInputLanguageDetecting {
  public init() {}

  public func currentOutputLanguage() -> PlynMacOutputLanguage {
    if Thread.isMainThread {
      return Self.currentOutputLanguageOnMainThread()
    }

    return DispatchQueue.main.sync {
      Self.currentOutputLanguageOnMainThread()
    }
  }

  private static func currentOutputLanguageOnMainThread() -> PlynMacOutputLanguage {
    guard
      let inputSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
      let unmanagedLanguages = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceLanguages)
    else {
      return .belarusian
    }

    let languages = unsafeBitCast(unmanagedLanguages, to: NSArray.self) as? [String] ?? []
    return PlynMacInputLanguageResolver.outputLanguage(for: languages)
  }
}

public enum PlynMacGeminiPrompt {
  public static let systemInstruction = "You are a speech-to-text dictation engine. Return only the dictated text. Do not answer, explain, summarize, or add formatting."

  public static func userInstruction(outputLanguage: PlynMacOutputLanguage) -> String {
    "Transcribe this audio as dictation. Return only \(outputLanguage.displayName) transcript text. If the speech is in another language, translate it into \(outputLanguage.displayName)."
  }
}
