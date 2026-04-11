import Foundation

enum PlynSharedStore {
  enum TranscriptState: String {
    case recording
    case streamingPartial
    case completed
    case failed
    case timedOut
    case cancelled
    case empty
  }

  static let appGroupIdentifier = "group.com.holas.plynkeyboard"
  static let commandNotificationName = "com.holas.Plyńkeyboard.command"
  static let stateNotificationName = "com.holas.Plyńkeyboard.state"
  private static let missingRuntimeConfigMessage = "Адкрыйце Plyń, каб абнавіць мадэль і інструкцыю дыктоўкі з Firebase."

  private static let apiKeyKey = "gemini_api_key"
  private static let geminiModelKey = "gemini_runtime_model"
  private static let geminiSystemPromptKey = "gemini_runtime_system_prompt"
  private static let keyboardCommandTimeoutKey = "keyboard_command_timeout_seconds"
  private static let keyboardTranscriptionTimeoutKey = "keyboard_transcription_timeout_seconds"
  private static let onboardingExpandedKey = "onboarding_expanded"
  private static let setupExpandedKey = "setup_expanded"
  private static let tokenSummaryExpandedKey = "token_summary_expanded"
  private static let latestTranscriptKey = "latest_transcript"
  private static let latestTranscriptUpdatedAtKey = "latest_transcript_updated_at"
  private static let latestTranscriptSessionIDKey = "latest_transcript_session_id"
  private static let latestTranscriptSequenceKey = "latest_transcript_sequence"
  private static let latestTranscriptIsFinalKey = "latest_transcript_is_final"
  private static let latestTranscriptStateKey = "latest_transcript_state"
  private static let latestTranscriptErrorCodeKey = "latest_transcript_error_code"
  private static let sessionActiveKey = "ios_session_active"
  private static let keyboardVisibleKey = "ios_keyboard_visible"
  private static let sessionHeartbeatUpdatedAtKey = "ios_session_heartbeat_updated_at"
  private static let sessionRecoveryAttemptUpdatedAtKey = "ios_session_recovery_attempt_updated_at"
  private static let keyboardCommandKey = "ios_keyboard_command"
  private static let keyboardCommandUpdatedAtKey = "ios_keyboard_command_updated_at"
  private static let keyboardStatusKey = "ios_keyboard_status"
  private static let keyboardStatusUpdatedAtKey = "ios_keyboard_status_updated_at"
  private static let keyboardLaunchDebugKey = "ios_keyboard_launch_debug"
  private static let keyboardDebugLogKey = "ios_keyboard_debug_log"
  private static let companionDebugLogKey = "ios_companion_debug_log"
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
  private static let lastRequestTokenInputKey = "gemini_last_request_input_tokens"
  private static let lastRequestTokenCachedInputKey = "gemini_last_request_cached_input_tokens"
  private static let lastRequestTokenOutputKey = "gemini_last_request_output_tokens"
  private static let lastRequestTokenTotalKey = "gemini_last_request_total_tokens"
  private static let lastRequestTokenInputTextKey = "gemini_last_request_input_text_tokens"
  private static let lastRequestTokenInputAudioKey = "gemini_last_request_input_audio_tokens"
  private static let lastRequestTokenInputImageKey = "gemini_last_request_input_image_tokens"
  private static let lastRequestTokenInputVideoKey = "gemini_last_request_input_video_tokens"
  private static let lastRequestTokenInputDocumentKey = "gemini_last_request_input_document_tokens"
  private static let lastRequestTokenCachedInputTextKey = "gemini_last_request_cached_input_text_tokens"
  private static let lastRequestTokenCachedInputAudioKey = "gemini_last_request_cached_input_audio_tokens"
  private static let lastRequestTokenCachedInputImageKey = "gemini_last_request_cached_input_image_tokens"
  private static let lastRequestTokenCachedInputVideoKey = "gemini_last_request_cached_input_video_tokens"
  private static let lastRequestTokenCachedInputDocumentKey = "gemini_last_request_cached_input_document_tokens"
  private static let lastRequestTokenOutputTextKey = "gemini_last_request_output_text_tokens"
  private static let lastRequestTokenOutputAudioKey = "gemini_last_request_output_audio_tokens"
  private static let lastRequestTokenOutputImageKey = "gemini_last_request_output_image_tokens"
  private static let lastRequestTokenOutputVideoKey = "gemini_last_request_output_video_tokens"
  private static let lastRequestTokenOutputDocumentKey = "gemini_last_request_output_document_tokens"
  private static let defaultKeyboardCommandTimeout: TimeInterval = 2.0
  private static let defaultKeyboardTranscriptionTimeout: TimeInterval = 12.0

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

    struct RequestSummary {
      let inputTokens: Int
      let cachedInputTokens: Int
      let outputTokens: Int
      let totalTokens: Int
      let inputByModality: ModalitySummary
      let cachedInputByModality: ModalitySummary
      let outputByModality: ModalitySummary

      static let zero = RequestSummary(
        inputTokens: 0,
        cachedInputTokens: 0,
        outputTokens: 0,
        totalTokens: 0,
        inputByModality: .zero,
        cachedInputByModality: .zero,
        outputByModality: .zero
      )

      init(
        inputTokens: Int,
        cachedInputTokens: Int,
        outputTokens: Int,
        totalTokens: Int,
        inputByModality: ModalitySummary,
        cachedInputByModality: ModalitySummary,
        outputByModality: ModalitySummary
      ) {
        self.inputTokens = inputTokens
        self.cachedInputTokens = cachedInputTokens
        self.outputTokens = outputTokens
        self.totalTokens = totalTokens
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
          "inputByModality": inputByModality.asDictionary(),
          "cachedInputByModality": cachedInputByModality.asDictionary(),
          "outputByModality": outputByModality.asDictionary(),
        ]
      }
    }

    let inputTokens: Int
    let cachedInputTokens: Int
    let outputTokens: Int
    let totalTokens: Int
    let requestCount: Int
    let lastRequest: RequestSummary
    let inputByModality: ModalitySummary
    let cachedInputByModality: ModalitySummary
    let outputByModality: ModalitySummary

    static let zero = TokenUsageSummary(
      inputTokens: 0,
      cachedInputTokens: 0,
      outputTokens: 0,
      totalTokens: 0,
      requestCount: 0,
      lastRequest: .zero,
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
      lastRequest: RequestSummary,
      inputByModality: ModalitySummary,
      cachedInputByModality: ModalitySummary,
      outputByModality: ModalitySummary
    ) {
      self.inputTokens = inputTokens
      self.cachedInputTokens = cachedInputTokens
      self.outputTokens = outputTokens
      self.totalTokens = totalTokens
      self.requestCount = requestCount
      self.lastRequest = lastRequest
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
      lastRequest = RequestSummary(usageMetadata: usageMetadata) ?? .zero
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
        "lastRequest": lastRequest.asDictionary(),
        "inputByModality": inputByModality.asDictionary(),
        "cachedInputByModality": cachedInputByModality.asDictionary(),
        "outputByModality": outputByModality.asDictionary(),
      ]
    }
  }

  private static var appGroupDefaults: UserDefaults? {
    UserDefaults(suiteName: appGroupIdentifier)
  }

  private static var defaults: UserDefaults {
    appGroupDefaults ?? .standard
  }

  private static func log(_ message: String) {
    NSLog("[PlynSharedStore] \(message)")
  }

  static func geminiModel() -> String? {
    let storedModel = normalizeGeminiModel(defaults.string(forKey: geminiModelKey))
    return storedModel.isEmpty ? nil : storedModel
  }

  static func saveGeminiModel(_ model: String) {
    defaults.set(normalizeGeminiModel(model), forKey: geminiModelKey)
    defaults.synchronize()
  }

  static func normalizeGeminiModel(_ rawModel: String?) -> String {
    rawModel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
  }

  static func geminiSystemPrompt() -> String? {
    let prompt = defaults.string(forKey: geminiSystemPromptKey)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return prompt.isEmpty ? nil : prompt
  }

  static func saveGeminiSystemPrompt(_ prompt: String) {
    defaults.set(prompt.trimmingCharacters(in: .whitespacesAndNewlines), forKey: geminiSystemPromptKey)
    defaults.synchronize()
  }

  static func keyboardCommandTimeout() -> TimeInterval {
    positiveTimeInterval(
      defaults.object(forKey: keyboardCommandTimeoutKey),
      fallback: defaultKeyboardCommandTimeout
    )
  }

  static func saveKeyboardCommandTimeout(_ timeout: TimeInterval) {
    defaults.set(validKeyboardTimeout(timeout) ?? defaultKeyboardCommandTimeout, forKey: keyboardCommandTimeoutKey)
    defaults.synchronize()
  }

  static func keyboardTranscriptionTimeout() -> TimeInterval {
    positiveTimeInterval(
      defaults.object(forKey: keyboardTranscriptionTimeoutKey),
      fallback: defaultKeyboardTranscriptionTimeout
    )
  }

  static func saveKeyboardTranscriptionTimeout(_ timeout: TimeInterval) {
    defaults.set(validKeyboardTimeout(timeout) ?? defaultKeyboardTranscriptionTimeout, forKey: keyboardTranscriptionTimeoutKey)
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

  static func sectionExpansionState() -> [String: Bool] {
    var state: [String: Bool] = [:]

    if defaults.object(forKey: onboardingExpandedKey) != nil {
      state["onboardingExpanded"] = defaults.bool(forKey: onboardingExpandedKey)
    }

    if defaults.object(forKey: setupExpandedKey) != nil {
      state["setupExpanded"] = defaults.bool(forKey: setupExpandedKey)
    }

    if defaults.object(forKey: tokenSummaryExpandedKey) != nil {
      state["tokenSummaryExpanded"] = defaults.bool(forKey: tokenSummaryExpandedKey)
    }

    return state
  }

  static func saveSectionExpansionState(
    onboardingExpanded: Bool?,
    setupExpanded: Bool?,
    tokenSummaryExpanded: Bool?
  ) {
    if let onboardingExpanded {
      defaults.set(onboardingExpanded, forKey: onboardingExpandedKey)
    }

    if let setupExpanded {
      defaults.set(setupExpanded, forKey: setupExpandedKey)
    }

    if let tokenSummaryExpanded {
      defaults.set(tokenSummaryExpanded, forKey: tokenSummaryExpandedKey)
    }

    defaults.synchronize()
  }

  static func isSessionActive() -> Bool {
    defaults.bool(forKey: sessionActiveKey)
  }

  static func saveSessionActive(_ active: Bool) {
    defaults.set(active, forKey: sessionActiveKey)
    if active {
      refreshSessionHeartbeat()
    } else {
      defaults.removeObject(forKey: sessionHeartbeatUpdatedAtKey)
    }
    saveKeyboardStatus(active ? .ready : .inactive)
    defaults.synchronize()
    postStateNotification()
  }

  static func isKeyboardVisible() -> Bool {
    defaults.bool(forKey: keyboardVisibleKey)
  }

  static func saveKeyboardVisible(_ visible: Bool) {
    defaults.set(visible, forKey: keyboardVisibleKey)
    defaults.synchronize()
    postStateNotification()
  }

  static func refreshSessionHeartbeat() {
    defaults.set(Date().timeIntervalSince1970, forKey: sessionHeartbeatUpdatedAtKey)
    defaults.synchronize()
  }

  static func markSessionRecoveryAttempt() {
    defaults.set(Date().timeIntervalSince1970, forKey: sessionRecoveryAttemptUpdatedAtKey)
    defaults.synchronize()
    postStateNotification()
  }

  static func sessionHeartbeatTimestamp() -> Date? {
    date(forKey: sessionHeartbeatUpdatedAtKey)
  }

  static func sessionRecoveryAttemptTimestamp() -> Date? {
    date(forKey: sessionRecoveryAttemptUpdatedAtKey)
  }

  static func saveKeyboardLaunchDebug(_ message: String) {
    let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedMessage.isEmpty else {
      return
    }

    let timestamp = ISO8601DateFormatter().string(from: Date())
    let entry = "[\(timestamp)] \(trimmedMessage)"
    defaults.set(entry, forKey: keyboardLaunchDebugKey)
    appendDebugLog(entry, forKey: keyboardDebugLogKey)
    defaults.synchronize()
  }

  static func keyboardDebugLog() -> String {
    defaults.string(forKey: keyboardDebugLogKey) ?? ""
  }

  static func appendCompanionDebugLog(_ message: String) {
    let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedMessage.isEmpty else {
      return
    }

    let timestamp = ISO8601DateFormatter().string(from: Date())
    let entry = "[\(timestamp)] \(trimmedMessage)"
    appendDebugLog(entry, forKey: companionDebugLogKey)
    defaults.synchronize()
  }

  static func companionDebugLog() -> String {
    defaults.string(forKey: companionDebugLogKey) ?? ""
  }

  static func clearDebugSnapshot() {
    defaults.removeObject(forKey: keyboardLaunchDebugKey)
    defaults.removeObject(forKey: keyboardDebugLogKey)
    defaults.removeObject(forKey: companionDebugLogKey)
    defaults.removeObject(forKey: sessionRecoveryAttemptUpdatedAtKey)
    defaults.removeObject(forKey: sessionHeartbeatUpdatedAtKey)
    defaults.synchronize()
  }

  static func debugSnapshot() -> [String: Any] {
    [
      "usesAppGroupDefaults": appGroupDefaults != nil,
      "appGroupIdentifier": appGroupIdentifier,
      "hasApiKey": hasApiKey(),
      "keyboardVisible": isKeyboardVisible(),
      "keyboardStatus": keyboardStatus().rawValue,
      "keyboardCommand": keyboardCommand().rawValue,
      "keyboardStatusUpdatedAt": bridgeValue(dateTimestamp(forKey: keyboardStatusUpdatedAtKey)),
      "keyboardCommandUpdatedAt": bridgeValue(dateTimestamp(forKey: keyboardCommandUpdatedAtKey)),
      "keyboardLaunchDebug": defaults.string(forKey: keyboardLaunchDebugKey) ?? "",
      "keyboardDebugLog": keyboardDebugLog(),
      "sessionActive": isSessionActive(),
      "sessionHeartbeatUpdatedAt": bridgeValue(dateTimestamp(forKey: sessionHeartbeatUpdatedAtKey)),
      "sessionRecoveryAttemptUpdatedAt": bridgeValue(dateTimestamp(forKey: sessionRecoveryAttemptUpdatedAtKey)),
      "companionDebugLog": companionDebugLog(),
    ]
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

  static func mergeStreamTranscript(existing: String, incoming: String) -> String {
    guard !incoming.isEmpty else {
      return existing
    }

    let normalizedIncoming = incoming

    if existing.isEmpty {
      return normalizedIncoming
    }

    if normalizedIncoming.hasPrefix(existing) {
      return normalizedIncoming
    }

    if existing.hasPrefix(normalizedIncoming) {
      return existing
    }

    let maxOverlap = min(existing.count, normalizedIncoming.count)
    for overlap in stride(from: maxOverlap, through: 1, by: -1) {
      if existing.suffix(overlap) == normalizedIncoming.prefix(overlap) {
        return existing + normalizedIncoming.dropFirst(overlap)
      }
    }

    return existing + normalizedIncoming
  }

  static func transcriptText(from parts: [[String: Any]]) -> String {
    parts
      .compactMap { $0["text"] as? String }
      .joined()
  }

  static func transcriptInsertionPrefix(before existingText: String, incoming: String) -> String {
    let normalizedIncoming = incoming.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalizedIncoming.isEmpty else {
      return ""
    }

    return shouldInsertTranscriptSeparator(between: existingText, and: normalizedIncoming) ? " " : ""
  }

  static func tokenUsageSummary() -> TokenUsageSummary {
    TokenUsageSummary(
      inputTokens: defaults.integer(forKey: tokenInputKey),
      cachedInputTokens: defaults.integer(forKey: tokenCachedInputKey),
      outputTokens: defaults.integer(forKey: tokenOutputKey),
      totalTokens: defaults.integer(forKey: tokenTotalKey),
      requestCount: defaults.integer(forKey: tokenRequestCountKey),
      lastRequest: TokenUsageSummary.RequestSummary(
        inputTokens: defaults.integer(forKey: lastRequestTokenInputKey),
        cachedInputTokens: defaults.integer(forKey: lastRequestTokenCachedInputKey),
        outputTokens: defaults.integer(forKey: lastRequestTokenOutputKey),
        totalTokens: defaults.integer(forKey: lastRequestTokenTotalKey),
        inputByModality: TokenUsageSummary.ModalitySummary(
          text: defaults.integer(forKey: lastRequestTokenInputTextKey),
          audio: defaults.integer(forKey: lastRequestTokenInputAudioKey),
          image: defaults.integer(forKey: lastRequestTokenInputImageKey),
          video: defaults.integer(forKey: lastRequestTokenInputVideoKey),
          document: defaults.integer(forKey: lastRequestTokenInputDocumentKey)
        ),
        cachedInputByModality: TokenUsageSummary.ModalitySummary(
          text: defaults.integer(forKey: lastRequestTokenCachedInputTextKey),
          audio: defaults.integer(forKey: lastRequestTokenCachedInputAudioKey),
          image: defaults.integer(forKey: lastRequestTokenCachedInputImageKey),
          video: defaults.integer(forKey: lastRequestTokenCachedInputVideoKey),
          document: defaults.integer(forKey: lastRequestTokenCachedInputDocumentKey)
        ),
        outputByModality: TokenUsageSummary.ModalitySummary(
          text: defaults.integer(forKey: lastRequestTokenOutputTextKey),
          audio: defaults.integer(forKey: lastRequestTokenOutputAudioKey),
          image: defaults.integer(forKey: lastRequestTokenOutputImageKey),
          video: defaults.integer(forKey: lastRequestTokenOutputVideoKey),
          document: defaults.integer(forKey: lastRequestTokenOutputDocumentKey)
        )
      ),
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
    defaults.set(summary.lastRequest.inputTokens, forKey: lastRequestTokenInputKey)
    defaults.set(summary.lastRequest.cachedInputTokens, forKey: lastRequestTokenCachedInputKey)
    defaults.set(summary.lastRequest.outputTokens, forKey: lastRequestTokenOutputKey)
    defaults.set(summary.lastRequest.totalTokens, forKey: lastRequestTokenTotalKey)
    defaults.set(summary.lastRequest.inputByModality.text, forKey: lastRequestTokenInputTextKey)
    defaults.set(summary.lastRequest.inputByModality.audio, forKey: lastRequestTokenInputAudioKey)
    defaults.set(summary.lastRequest.inputByModality.image, forKey: lastRequestTokenInputImageKey)
    defaults.set(summary.lastRequest.inputByModality.video, forKey: lastRequestTokenInputVideoKey)
    defaults.set(summary.lastRequest.inputByModality.document, forKey: lastRequestTokenInputDocumentKey)
    defaults.set(summary.lastRequest.cachedInputByModality.text, forKey: lastRequestTokenCachedInputTextKey)
    defaults.set(summary.lastRequest.cachedInputByModality.audio, forKey: lastRequestTokenCachedInputAudioKey)
    defaults.set(summary.lastRequest.cachedInputByModality.image, forKey: lastRequestTokenCachedInputImageKey)
    defaults.set(summary.lastRequest.cachedInputByModality.video, forKey: lastRequestTokenCachedInputVideoKey)
    defaults.set(summary.lastRequest.cachedInputByModality.document, forKey: lastRequestTokenCachedInputDocumentKey)
    defaults.set(summary.lastRequest.outputByModality.text, forKey: lastRequestTokenOutputTextKey)
    defaults.set(summary.lastRequest.outputByModality.audio, forKey: lastRequestTokenOutputAudioKey)
    defaults.set(summary.lastRequest.outputByModality.image, forKey: lastRequestTokenOutputImageKey)
    defaults.set(summary.lastRequest.outputByModality.video, forKey: lastRequestTokenOutputVideoKey)
    defaults.set(summary.lastRequest.outputByModality.document, forKey: lastRequestTokenOutputDocumentKey)
    defaults.synchronize()
  }

  static func resetTokenUsageSummary() {
    [
      tokenInputKey,
      tokenCachedInputKey,
      tokenOutputKey,
      tokenTotalKey,
      tokenRequestCountKey,
      tokenInputTextKey,
      tokenInputAudioKey,
      tokenInputImageKey,
      tokenInputVideoKey,
      tokenInputDocumentKey,
      tokenCachedInputTextKey,
      tokenCachedInputAudioKey,
      tokenCachedInputImageKey,
      tokenCachedInputVideoKey,
      tokenCachedInputDocumentKey,
      tokenOutputTextKey,
      tokenOutputAudioKey,
      tokenOutputImageKey,
      tokenOutputVideoKey,
      tokenOutputDocumentKey,
      lastRequestTokenInputKey,
      lastRequestTokenCachedInputKey,
      lastRequestTokenOutputKey,
      lastRequestTokenTotalKey,
      lastRequestTokenInputTextKey,
      lastRequestTokenInputAudioKey,
      lastRequestTokenInputImageKey,
      lastRequestTokenInputVideoKey,
      lastRequestTokenInputDocumentKey,
      lastRequestTokenCachedInputTextKey,
      lastRequestTokenCachedInputAudioKey,
      lastRequestTokenCachedInputImageKey,
      lastRequestTokenCachedInputVideoKey,
      lastRequestTokenCachedInputDocumentKey,
      lastRequestTokenOutputTextKey,
      lastRequestTokenOutputAudioKey,
      lastRequestTokenOutputImageKey,
      lastRequestTokenOutputVideoKey,
      lastRequestTokenOutputDocumentKey,
    ].forEach { defaults.removeObject(forKey: $0) }
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

  private static func shouldInsertTranscriptSeparator(between leftText: String, and rightText: String) -> Bool {
    guard
      let left = lastNonWhitespaceCharacter(in: leftText),
      let right = firstNonWhitespaceCharacter(in: rightText)
    else {
      return false
    }

    if isClosingPunctuation(right) || isOpeningDelimiter(left) {
      return false
    }

    if ["-", "'", "’"].contains(left) || ["-", "'", "’"].contains(right) {
      return false
    }

    if
      let leftIndex = lastNonWhitespaceIndex(in: leftText),
      leftIndex > leftText.startIndex,
      [".", ","].contains(left),
      let previousScalar = leftText[leftText.index(before: leftIndex)].asciiScalar,
      let rightScalar = right.asciiScalar,
      CharacterSet.decimalDigits.contains(previousScalar),
      CharacterSet.decimalDigits.contains(rightScalar)
    {
      return false
    }

    if left.isLetterOrNumber && right.isLetterOrNumber {
      return true
    }

    if isSpacingPunctuation(left), right.isLetterOrNumber || isQuoteLike(right) {
      return true
    }

    return ([")", "]", "}"].contains(left) || isQuoteLike(left)) && right.isLetterOrNumber
  }

  private static func lastNonWhitespaceCharacter(in value: String) -> Character? {
    value.last(where: { !$0.isWhitespace })
  }

  private static func firstNonWhitespaceCharacter(in value: String) -> Character? {
    value.first(where: { !$0.isWhitespace })
  }

  private static func lastNonWhitespaceIndex(in value: String) -> String.Index? {
    value.indices.last(where: { !value[$0].isWhitespace })
  }

  private static func isClosingPunctuation(_ value: Character) -> Bool {
    [".", ",", "!", "?", ";", ":", "%", ")", "]", "}"].contains(value)
  }

  private static func isOpeningDelimiter(_ value: Character) -> Bool {
    ["(", "[", "{"].contains(value)
  }

  private static func isSpacingPunctuation(_ value: Character) -> Bool {
    [".", ",", "!", "?", ";", ":"].contains(value)
  }

  private static func isQuoteLike(_ value: Character) -> Bool {
    ["\"", "'", "“", "”", "«", "»"].contains(value)
  }

  private static func positiveTimeInterval(_ value: Any?, fallback: TimeInterval) -> TimeInterval {
    switch value {
    case let number as NSNumber:
      return validKeyboardTimeout(number.doubleValue) ?? fallback
    case let string as String:
      return validKeyboardTimeout(Double(string) ?? .zero) ?? fallback
    default:
      return fallback
    }
  }

  private static func validKeyboardTimeout(_ timeout: TimeInterval) -> TimeInterval? {
    guard timeout.isFinite, timeout > .zero else {
      return nil
    }

    return timeout
  }

  private static func appendDebugLog(_ entry: String, forKey key: String) {
    let existingEntries = (defaults.string(forKey: key) ?? "")
      .split(separator: "\n")
      .map(String.init)
    let retainedEntries = Array((existingEntries + [entry]).suffix(60))
    defaults.set(retainedEntries.joined(separator: "\n"), forKey: key)
  }

  private static func dateTimestamp(forKey key: String) -> Double? {
    guard let timestamp = defaults.object(forKey: key) as? NSNumber else {
      return nil
    }

    return timestamp.doubleValue
  }

  private static func bridgeValue(_ value: Double?) -> Any {
    value ?? NSNull()
  }
}

private extension Character {
  var isLetterOrNumber: Bool {
    unicodeScalars.allSatisfy { CharacterSet.alphanumerics.contains($0) }
  }

  var asciiScalar: Unicode.Scalar? {
    unicodeScalars.first
  }
}
