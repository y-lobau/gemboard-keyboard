import Foundation

public enum PlynMacHoldTrigger: String, CaseIterable, Codable, Identifiable, Sendable {
  case functionGlobe
  case controlOption

  public var id: String { rawValue }

  public var title: String {
    switch self {
    case .functionGlobe:
      return "Fn / Globe"
    case .controlOption:
      return "Control + Option"
    }
  }
}

public enum PlynMacGeminiModel: String, CaseIterable, Codable, Identifiable, Sendable {
  case gemini25Flash = "gemini-2.5-flash"
  case gemini3FlashPreview = "gemini-3-flash-preview"

  public var id: String { rawValue }

  public var title: String {
    switch self {
    case .gemini25Flash:
      return "Gemini 2.5 Flash"
    case .gemini3FlashPreview:
      return "Gemini 3 Flash Preview"
    }
  }

  public var costRates: PlynMacTranscriptionCostRates {
    switch self {
    case .gemini25Flash:
      return PlynMacTranscriptionCostRates(
        inputText: 0.30,
        inputAudio: 1.00,
        inputCacheText: 0.03,
        inputCacheAudio: 0.10,
        outputText: 2.50
      )
    case .gemini3FlashPreview:
      return PlynMacTranscriptionCostRates(
        inputText: 0.50,
        inputAudio: 1.00,
        inputCacheText: 0.05,
        inputCacheAudio: 0.10,
        outputText: 3.00
      )
    }
  }
}

public struct PlynMacTranscriptionCostRates: Equatable, Sendable {
  public let inputText: Double
  public let inputAudio: Double
  public let inputCacheText: Double
  public let inputCacheAudio: Double
  public let outputText: Double

  public init(
    inputText: Double,
    inputAudio: Double,
    inputCacheText: Double,
    inputCacheAudio: Double,
    outputText: Double
  ) {
    self.inputText = inputText
    self.inputAudio = inputAudio
    self.inputCacheText = inputCacheText
    self.inputCacheAudio = inputCacheAudio
    self.outputText = outputText
  }
}

public enum PlynMacHoldEvent: Equatable, Sendable {
  case pressed(PlynMacHoldTrigger)
  case released(PlynMacHoldTrigger)
}

public enum PlynMacHoldTransition: Equatable, Sendable {
  case started
  case stopped
  case unchanged
}

public struct PlynMacHoldTriggerStateMachine: Sendable {
  public let trigger: PlynMacHoldTrigger
  public private(set) var isHeld: Bool

  public init(trigger: PlynMacHoldTrigger, isHeld: Bool = false) {
    self.trigger = trigger
    self.isHeld = isHeld
  }

  public mutating func handle(_ event: PlynMacHoldEvent) -> PlynMacHoldTransition {
    switch event {
    case let .pressed(eventTrigger):
      guard eventTrigger == trigger, !isHeld else {
        return .unchanged
      }
      isHeld = true
      return .started
    case let .released(eventTrigger):
      guard eventTrigger == trigger, isHeld else {
        return .unchanged
      }
      isHeld = false
      return .stopped
    }
  }
}

public struct PlynMacPermissionSnapshot: Equatable, Sendable {
  public let microphoneGranted: Bool
  public let inputMonitoringGranted: Bool
  public let accessibilityGranted: Bool

  public static let granted = PlynMacPermissionSnapshot(
    microphoneGranted: true,
    inputMonitoringGranted: true,
    accessibilityGranted: true
  )

  public init(
    microphoneGranted: Bool,
    inputMonitoringGranted: Bool,
    accessibilityGranted: Bool
  ) {
    self.microphoneGranted = microphoneGranted
    self.inputMonitoringGranted = inputMonitoringGranted
    self.accessibilityGranted = accessibilityGranted
  }

  public var isReady: Bool {
    microphoneGranted && inputMonitoringGranted && accessibilityGranted
  }

  public var firstMissingMessage: String? {
    if !microphoneGranted {
      return "Microphone permission is required."
    }
    if !inputMonitoringGranted {
      return "Input Monitoring permission is required."
    }
    if !accessibilityGranted {
      return "Accessibility permission is required."
    }
    return nil
  }
}

public enum PlynMacDictationState: Equatable, Sendable {
  case idle
  case recording
  case transcribing
  case inserting
  case failed(String)
}

public protocol PlynMacAudioRecording: AnyObject, Sendable {
  func startRecording() async throws
  func stopRecording() async throws -> URL
}

public protocol PlynMacTranscribing: AnyObject, Sendable {
  func transcribe(audioURL: URL) async throws -> String
}

public protocol PlynMacTextInserting: AnyObject, Sendable {
  func insert(_ text: String) async throws
}

public protocol PlynMacConfigurationProviding: Sendable {
  var isReady: Bool { get }
}

public protocol PlynMacPermissionChecking: Sendable {
  func currentSnapshot() -> PlynMacPermissionSnapshot
}

public struct PlynMacGeminiConfiguration: Equatable, Sendable {
  public let apiKey: String
  public let model: String
  public let systemPrompt: String

  public init(apiKey: String, model: String, systemPrompt: String) {
    self.apiKey = apiKey
    self.model = model
    self.systemPrompt = systemPrompt
  }

  public var isReady: Bool {
    !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
      !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
      !systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
}

public protocol PlynMacGeminiConfigurationProviding: Sendable {
  func geminiConfiguration() throws -> PlynMacGeminiConfiguration
}

public enum PlynMacError: LocalizedError, Sendable {
  case missingConfiguration
  case missingAudio
  case emptyTranscript
  case invalidGeminiEndpoint
  case invalidGeminiResponse
  case serviceError(String)
  case eventTapUnavailable

  public var errorDescription: String? {
    switch self {
    case .missingConfiguration:
      return "Save the Gemini setup before dictating."
    case .missingAudio:
      return "No captured audio was available."
    case .emptyTranscript:
      return "Gemini returned an empty transcript."
    case .invalidGeminiEndpoint:
      return "The Gemini endpoint could not be prepared."
    case .invalidGeminiResponse:
      return "The transcription service returned an invalid response."
    case let .serviceError(message):
      return message
    case .eventTapUnavailable:
      return "Input Monitoring permission is required."
    }
  }
}
