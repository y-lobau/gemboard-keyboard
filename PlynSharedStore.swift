import Foundation

enum PlyńSharedStore {
  enum TranscriptState: String {
    case recording
    case streamingPartial
    case completed
    case failed
    case timedOut
    case cancelled
    case empty
  }

  static let appGroupIdentifier = "group.com.holas.Plyńkeyboard"
  static let commandNotificationName = "com.holas.Plyńkeyboard.command"
  static let stateNotificationName = "com.holas.Plyńkeyboard.state"
  private static let missingRuntimeConfigMessage = "Адкрыйце Plyń, каб абнавіць мадэль і інструкцыю дыктоўкі з Firebase."

  private static let apiKeyKey = "gemini_api_key"
  private static let geminiModelKey = "gemini_runtime_model"
  private static let geminiSystemPromptKey = "gemini_runtime_system_prompt"
  private static let latestTranscriptKey = "latest_transcript"
  private static let latestTranscriptUpdatedAtKey = "latest_transcript_updated_at"
  private static let latestTranscriptSessionIDKey = "latest_transcript_session_id"
  private static let latestTranscriptSequenceKey = "latest_transcript_sequence"
  private static let latestTranscriptIsFinalKey = "latest_transcript_is_final"
  private static let latestTranscriptStateKey = "latest_transcript_state"
  private static let latestTranscriptErrorCodeKey = "latest_transcript_error_code"
  private static let sessionActiveKey = "ios_session_active"
  private static let keyboardCommandKey = "ios_keyboard_command"
  private static let keyboardCommandUpdatedAtKey = "ios_keyboard_command_updated_at"
  private static let keyboardStatusKey = "ios_keyboard_status"
  private static let keyboardStatusUpdatedAtKey = "ios_keyboard_status_updated_at"
  private static let tokenInputKey = "gemini_total_input_tokens"
  private static let tokenCachedInputKey = "gemini_total_cached_input_tokens"
  private static let tokenOutputKey = "gemini_total_output_tokens"
  private static let tokenTotalKey = "gemini_total_tokens"
  private static let tokenRequestCountKey = "gemini_total_request_count"
  private static let tokenInputTextKey = "gemini_total_input_text_tokens"
  private static let tokenInputAudioKey = "gemini_total_input_audio_tokens"
  private static let tokenInputImageKey = "gemini_total_input_image_tokens"
  private static let tokenInputVideoKey = "gemini_total_input_video_tokens"
  private static let tokenInputDocumentKey = "gemini_total_input_document_tokens"
  private static let tokenCachedInputTextKey = "gemini_total_cached_input_text_tokens"
  private static let tokenCachedInputAudioKey = "gemini_total_cached_input_audio_tokens"
  private static let tokenCachedInputImageKey = "gemini_total_cached_input_image_tokens"
  private static let tokenCachedInputVideoKey = "gemini_total_cached_input_video_tokens"
  private static let tokenCachedInputDocumentKey = "gemini_total_cached_input_document_tokens"
  private static let tokenOutputTextKey = "gemini_total_output_text_tokens"
  private static let tokenOutputAudioKey = "gemini_total_output_audio_tokens"
  private static let tokenOutputImageKey = "gemini_total_output_image_tokens"
  private static let tokenOutputVideoKey = "gemini_total_output_video_tokens"
  private static let tokenOutputDocumentKey = "gemini_total_output_document_tokens"

  enum KeyboardCommand: String {
    case none
    case startCapture
    case stopCapture
  }

  enum KeyboardStatus: String {
    case inactive
    case ready
    case recording
    case transcribing
    case failed
  }

  struct TranscriptSnapshot {
    let text: String
    let sessionID: String
    let sequence: Int
    let isFinal: Bool
    let state: TranscriptState
    let errorCode: String?
    let updatedAt: Date
  }

  struct TokenUsageSummary {
    struct ModalitySummary {
      let text: Int
      let audio: Int
      let image: Int
      let video: Int
      let document: Int

      static let zero = ModalitySummary(text: 0, audio: 0, image: 0, video: 0, document: 0)

      init(text: Int, audio: Int, image: Int, video: Int, document: Int) {
        self.text = text
        self.audio = audio
        self.image = image
        self.video = video
        self.document = document
      }

      init(tokenDetails: [[String: Any]]?) {
        var summary = ModalitySummary.zero

        for tokenDetail in tokenDetails ?? [] {
          let tokenCount = (tokenDetail["tokenCount"] as? NSNumber)?.intValue ?? 0
          switch (tokenDetail["modality"] as? String)?.uppercased() {
          case "TEXT":
            summary = ModalitySummary(
              text: summary.text + tokenCount,
              audio: summary.audio,
              image: summary.image,
              video: summary.video,
              document: summary.document
            )
          case "AUDIO":
            summary = ModalitySummary(
              text: summary.text,
              audio: summary.audio + tokenCount,
              image: summary.image,
              video: summary.video,
              document: summary.document
            )
          case "IMAGE":
            summary = ModalitySummary(
              text: summary.text,
              audio: summary.audio,
              image: summary.image + tokenCount,
              video: summary.video,
              document: summary.document
            )
          case "VIDEO":
            summary = ModalitySummary(
              text: summary.text,
              audio: summary.audio,
              image: summary.image,
              video: summary.video + tokenCount,
              document: summary.document
            )
          case "DOCUMENT":
            summary = ModalitySummary(
              text: summary.text,
              audio: summary.audio,
              image: summary.image,
              video: summary.video,
              document: summary.document + tokenCount
            )
          default:
            continue
          }
        }

        self = summary
      }

      func asDictionary() -> [String: Int] {
        [
          "text": text,
          "audio": audio,
          "image": image,
          "video": video,
          "document": document,
        ]
      }
    }

    let inputTokens: Int
    let cachedInputTokens: Int
    let outputTokens: Int
    let totalTokens: Int
    let requestCount: Int
    let inputByModality: ModalitySummary
    let cachedInputByModality: ModalitySummary
    let outputByModality: ModalitySummary

    static let zero = TokenUsageSummary(
      inputTokens: 0,
      cachedInputTokens: 0,
      outputTokens: 0,
      totalTokens: 0,
      requestCount: 0,
      inputByModality: .zero,
      cachedInputByModality: .zero,
      outputByModality: .zero
    )

    init(
      inputTokens: Int,
      cachedInputTokens: Int,
      outputTokens: Int,
      totalTokens: Int,
      requestCount: Int,
      inputByModality: ModalitySummary,
      cachedInputByModality: ModalitySummary,
      outputByModality: ModalitySummary
    ) {
      self.inputTokens = inputTokens
      self.cachedInputTokens = cachedInputTokens
      self.outputTokens = outputTokens
      self.totalTokens = totalTokens
      self.requestCount = requestCount
      self.inputByModality = inputByModality
      self.cachedInputByModality = cachedInputByModality
      self.outputByModality = outputByModality
    }

    init?(usageMetadata: [String: Any]?) {
      guard
        let usageMetadata,
        let totalTokens = (usageMetadata["totalTokenCount"] as? NSNumber)?.intValue
      else {
        return nil
      }

      inputTokens = (usageMetadata["promptTokenCount"] as? NSNumber)?.intValue ?? 0
      cachedInputTokens = (usageMetadata["cachedContentTokenCount"] as? NSNumber)?.intValue ?? 0
      outputTokens = (usageMetadata["candidatesTokenCount"] as? NSNumber)?.intValue ?? 0
      self.totalTokens = totalTokens
      requestCount = 1
      inputByModality = ModalitySummary(tokenDetails: usageMetadata["promptTokensDetails"] as? [[String: Any]])
      cachedInputByModality = ModalitySummary(tokenDetails: usageMetadata["cacheTokensDetails"] as? [[String: Any]])
      outputByModality = ModalitySummary(tokenDetails: usageMetadata["candidatesTokensDetails"] as? [[String: Any]])
    }

    func asDictionary() -> [String: Any] {
      [
        "inputTokens": inputTokens,
        "cachedInputTokens": cachedInputTokens,
        "outputTokens": outputTokens,
        "totalTokens": totalTokens,
        "requestCount": requestCount,
        "inputByModality": inputByModality.asDictionary(),
        "cachedInputByModality": cachedInputByModality.asDictionary(),
        "outputByModality": outputByModality.asDictionary(),
      ]
    }
  }

  private static var defaults: UserDefaults {
    UserDefaults(suiteName: appGroupIdentifier) ?? .standard
  }

  private static func log(_ message: String) {
    NSLog("[PlyńSharedStore] \(message)")
  }

  static func geminiModel() -> String? {
    let storedModel = defaults.string(forKey: geminiModelKey)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return storedModel.isEmpty ? nil : storedModel
  }

  static func saveGeminiModel(_ model: String) {
    defaults.set(model.trimmingCharacters(in: .whitespacesAndNewlines), forKey: geminiModelKey)
    defaults.synchronize()
  }

  static func geminiSystemPrompt() -> String? {
    let prompt = defaults.string(forKey: geminiSystemPromptKey)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return prompt.isEmpty ? nil : prompt
  }

  static func saveGeminiSystemPrompt(_ prompt: String) {
    defaults.set(prompt.trimmingCharacters(in: .whitespacesAndNewlines), forKey: geminiSystemPromptKey)
    defaults.synchronize()
  }

  static func geminiEndpointURL(apiKey: String) -> URL? {
    let escapedApiKey = apiKey.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? apiKey
    guard let model = geminiModel() else {
      return nil
    }

    return URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(escapedApiKey)")
  }

  static func geminiStreamEndpointURL(apiKey: String) -> URL? {
    let escapedApiKey = apiKey.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? apiKey
    guard let model = geminiModel() else {
      return nil
    }

    return URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):streamGenerateContent?alt=sse&key=\(escapedApiKey)")
  }

  static func missingRuntimeConfigError() -> NSError {
    NSError(domain: "PlyńConfig", code: 2, userInfo: [NSLocalizedDescriptionKey: missingRuntimeConfigMessage])
  }

  static func apiKey() -> String? {
    let key = defaults.string(forKey: apiKeyKey)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return key.isEmpty ? nil : key
  }

  static func hasApiKey() -> Bool {
    let present = apiKey() != nil
    log("hasApiKey present=\(present)")
    return present
  }

  static func saveApiKey(_ apiKey: String) {
    let trimmedApiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    defaults.set(trimmedApiKey, forKey: apiKeyKey)
    defaults.synchronize()
    log("saveApiKey length=\(trimmedApiKey.count) suite=\(appGroupIdentifier)")
  }

  static func isSessionActive() -> Bool {
    defaults.bool(forKey: sessionActiveKey)
  }

  static func saveSessionActive(_ active: Bool) {
    defaults.set(active, forKey: sessionActiveKey)
    saveKeyboardStatus(active ? .ready : .inactive)
    defaults.synchronize()
    postStateNotification()
  }

  static func keyboardCommand() -> KeyboardCommand {
    guard let rawValue = defaults.string(forKey: keyboardCommandKey), let command = KeyboardCommand(rawValue: rawValue) else {
      return .none
    }

    return command
  }

  static func saveKeyboardCommand(_ command: KeyboardCommand) {
    defaults.set(command.rawValue, forKey: keyboardCommandKey)
    defaults.set(Date().timeIntervalSince1970, forKey: keyboardCommandUpdatedAtKey)
    defaults.synchronize()
    postCommandNotification()
  }

  static func keyboardCommandTimestamp() -> Date? {
    date(forKey: keyboardCommandUpdatedAtKey)
  }

  static func keyboardStatus() -> KeyboardStatus {
    guard let rawValue = defaults.string(forKey: keyboardStatusKey), let status = KeyboardStatus(rawValue: rawValue) else {
      return isSessionActive() ? .ready : .inactive
    }

    return status
  }

  static func saveKeyboardStatus(_ status: KeyboardStatus) {
    defaults.set(status.rawValue, forKey: keyboardStatusKey)
    defaults.set(Date().timeIntervalSince1970, forKey: keyboardStatusUpdatedAtKey)
    defaults.synchronize()
    postStateNotification()
  }

  static func keyboardStatusTimestamp() -> Date? {
    date(forKey: keyboardStatusUpdatedAtKey)
  }

  static func saveLatestTranscript(_ transcript: String) {
    let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)

    if trimmedTranscript.isEmpty {
      clearLatestTranscript()
      return
    }

    let currentSessionID = defaults.string(forKey: latestTranscriptSessionIDKey) ?? UUID().uuidString
    let nextSequence = max(defaults.integer(forKey: latestTranscriptSequenceKey) + 1, 1)
    saveTranscriptSnapshot(
      trimmedTranscript,
      sessionID: currentSessionID,
      sequence: nextSequence,
      isFinal: true,
      state: .completed,
      errorCode: nil
    )
  }

  static func saveTranscriptSnapshot(
    _ transcript: String,
    sessionID: String,
    sequence: Int,
    isFinal: Bool,
    state: TranscriptState,
    errorCode: String?
  ) {
    let sanitizedTranscript: String

    switch state {
    case .empty, .failed, .timedOut, .cancelled:
      sanitizedTranscript = transcript
    default:
      sanitizedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    defaults.set(sanitizedTranscript, forKey: latestTranscriptKey)
    defaults.set(Date().timeIntervalSince1970, forKey: latestTranscriptUpdatedAtKey)
    defaults.set(sessionID, forKey: latestTranscriptSessionIDKey)
    defaults.set(max(sequence, 1), forKey: latestTranscriptSequenceKey)
    defaults.set(isFinal, forKey: latestTranscriptIsFinalKey)
    defaults.set(state.rawValue, forKey: latestTranscriptStateKey)
    defaults.set(errorCode, forKey: latestTranscriptErrorCodeKey)
    defaults.synchronize()
    postStateNotification()
  }

  static func latestTranscript() -> String? {
    let transcript = defaults.string(forKey: latestTranscriptKey)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return transcript.isEmpty ? nil : transcript
  }

  static func latestTranscriptTimestamp() -> Date? {
    let seconds = defaults.double(forKey: latestTranscriptUpdatedAtKey)
    guard seconds > 0 else {
      return nil
    }

    return Date(timeIntervalSince1970: seconds)
  }

  static func latestTranscriptSnapshot() -> TranscriptSnapshot? {
    guard
      let text = defaults.string(forKey: latestTranscriptKey),
      let updatedAt = latestTranscriptTimestamp()
    else {
      return nil
    }

    let sessionID = defaults.string(forKey: latestTranscriptSessionIDKey) ?? "legacy"
    let sequence = max(defaults.integer(forKey: latestTranscriptSequenceKey), 1)
    let isFinal = defaults.object(forKey: latestTranscriptIsFinalKey) == nil ? true : defaults.bool(forKey: latestTranscriptIsFinalKey)
    let stateRawValue = defaults.string(forKey: latestTranscriptStateKey) ?? (isFinal ? TranscriptState.completed.rawValue : TranscriptState.streamingPartial.rawValue)
    let state = TranscriptState(rawValue: stateRawValue) ?? (isFinal ? .completed : .streamingPartial)
    let errorCode = defaults.string(forKey: latestTranscriptErrorCodeKey)

    return TranscriptSnapshot(
      text: text,
      sessionID: sessionID,
      sequence: sequence,
      isFinal: isFinal,
      state: state,
      errorCode: errorCode,
      updatedAt: updatedAt
    )
  }

  static func clearLatestTranscript() {
    defaults.removeObject(forKey: latestTranscriptKey)
    defaults.removeObject(forKey: latestTranscriptUpdatedAtKey)
    defaults.removeObject(forKey: latestTranscriptSessionIDKey)
    defaults.removeObject(forKey: latestTranscriptSequenceKey)
    defaults.removeObject(forKey: latestTranscriptIsFinalKey)
    defaults.removeObject(forKey: latestTranscriptStateKey)
    defaults.removeObject(forKey: latestTranscriptErrorCodeKey)
    defaults.synchronize()
    postStateNotification()
  }

  static func tokenUsageSummary() -> TokenUsageSummary {
    TokenUsageSummary(
      inputTokens: defaults.integer(forKey: tokenInputKey),
      cachedInputTokens: defaults.integer(forKey: tokenCachedInputKey),
      outputTokens: defaults.integer(forKey: tokenOutputKey),
      totalTokens: defaults.integer(forKey: tokenTotalKey),
      requestCount: defaults.integer(forKey: tokenRequestCountKey),
      inputByModality: TokenUsageSummary.ModalitySummary(
        text: defaults.integer(forKey: tokenInputTextKey),
        audio: defaults.integer(forKey: tokenInputAudioKey),
        image: defaults.integer(forKey: tokenInputImageKey),
        video: defaults.integer(forKey: tokenInputVideoKey),
        document: defaults.integer(forKey: tokenInputDocumentKey)
      ),
      cachedInputByModality: TokenUsageSummary.ModalitySummary(
        text: defaults.integer(forKey: tokenCachedInputTextKey),
        audio: defaults.integer(forKey: tokenCachedInputAudioKey),
        image: defaults.integer(forKey: tokenCachedInputImageKey),
        video: defaults.integer(forKey: tokenCachedInputVideoKey),
        document: defaults.integer(forKey: tokenCachedInputDocumentKey)
      ),
      outputByModality: TokenUsageSummary.ModalitySummary(
        text: defaults.integer(forKey: tokenOutputTextKey),
        audio: defaults.integer(forKey: tokenOutputAudioKey),
        image: defaults.integer(forKey: tokenOutputImageKey),
        video: defaults.integer(forKey: tokenOutputVideoKey),
        document: defaults.integer(forKey: tokenOutputDocumentKey)
      )
    )
  }

  static func addTokenUsageSummary(_ summary: TokenUsageSummary?) {
    guard let summary else {
      return
    }

    let current = tokenUsageSummary()
    defaults.set(current.inputTokens + summary.inputTokens, forKey: tokenInputKey)
    defaults.set(current.cachedInputTokens + summary.cachedInputTokens, forKey: tokenCachedInputKey)
    defaults.set(current.outputTokens + summary.outputTokens, forKey: tokenOutputKey)
    defaults.set(current.totalTokens + summary.totalTokens, forKey: tokenTotalKey)
    defaults.set(current.requestCount + summary.requestCount, forKey: tokenRequestCountKey)
    defaults.set(current.inputByModality.text + summary.inputByModality.text, forKey: tokenInputTextKey)
    defaults.set(current.inputByModality.audio + summary.inputByModality.audio, forKey: tokenInputAudioKey)
    defaults.set(current.inputByModality.image + summary.inputByModality.image, forKey: tokenInputImageKey)
    defaults.set(current.inputByModality.video + summary.inputByModality.video, forKey: tokenInputVideoKey)
    defaults.set(current.inputByModality.document + summary.inputByModality.document, forKey: tokenInputDocumentKey)
    defaults.set(current.cachedInputByModality.text + summary.cachedInputByModality.text, forKey: tokenCachedInputTextKey)
    defaults.set(current.cachedInputByModality.audio + summary.cachedInputByModality.audio, forKey: tokenCachedInputAudioKey)
    defaults.set(current.cachedInputByModality.image + summary.cachedInputByModality.image, forKey: tokenCachedInputImageKey)
    defaults.set(current.cachedInputByModality.video + summary.cachedInputByModality.video, forKey: tokenCachedInputVideoKey)
    defaults.set(current.cachedInputByModality.document + summary.cachedInputByModality.document, forKey: tokenCachedInputDocumentKey)
    defaults.set(current.outputByModality.text + summary.outputByModality.text, forKey: tokenOutputTextKey)
    defaults.set(current.outputByModality.audio + summary.outputByModality.audio, forKey: tokenOutputAudioKey)
    defaults.set(current.outputByModality.image + summary.outputByModality.image, forKey: tokenOutputImageKey)
    defaults.set(current.outputByModality.video + summary.outputByModality.video, forKey: tokenOutputVideoKey)
    defaults.set(current.outputByModality.document + summary.outputByModality.document, forKey: tokenOutputDocumentKey)
    defaults.synchronize()
  }

  private static func date(forKey key: String) -> Date? {
    let seconds = defaults.double(forKey: key)
    guard seconds > 0 else {
      return nil
    }

    return Date(timeIntervalSince1970: seconds)
  }

  private static func postCommandNotification() {
    let center = CFNotificationCenterGetDarwinNotifyCenter()
    CFNotificationCenterPostNotification(center, CFNotificationName(commandNotificationName as CFString), nil, nil, true)
  }

  private static func postStateNotification() {
    let center = CFNotificationCenterGetDarwinNotifyCenter()
    CFNotificationCenterPostNotification(center, CFNotificationName(stateNotificationName as CFString), nil, nil, true)
  }
}
