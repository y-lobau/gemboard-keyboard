import Foundation

public final class PlynMacGeminiTranscriber: PlynMacTranscribing, @unchecked Sendable {
  private let configurationProvider: PlynMacGeminiConfigurationProviding
  private let languageDetector: PlynMacInputLanguageDetecting
  private let tokenUsageRecorder: PlynMacTokenUsageRecording?
  private let session: URLSession

  public init(
    configurationProvider: PlynMacGeminiConfigurationProviding,
    languageDetector: PlynMacInputLanguageDetecting = PlynMacInputSourceLanguageDetector(),
    tokenUsageRecorder: PlynMacTokenUsageRecording? = nil,
    session: URLSession = .shared
  ) {
    self.configurationProvider = configurationProvider
    self.languageDetector = languageDetector
    self.tokenUsageRecorder = tokenUsageRecorder
    self.session = session
  }

  public func transcribe(audioURL: URL) async throws -> String {
    let configuration = try configurationProvider.geminiConfiguration()
    guard configuration.isReady else {
      throw PlynMacError.missingConfiguration
    }

    let audioData = try Data(contentsOf: audioURL)
    let outputLanguage = languageDetector.currentOutputLanguage()
    PlynMacLogger.log("gemini request preparing audioBytes=\(audioData.count) model=\(configuration.model) language=\(outputLanguage.identifier)")
    let request = try makeRequest(
      configuration: configuration,
      audioData: audioData,
      outputLanguage: outputLanguage
    )
    let (data, response) = try await session.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw PlynMacError.invalidGeminiResponse
    }

    guard (200 ... 299).contains(httpResponse.statusCode) else {
      PlynMacLogger.log("gemini request failed status=\(httpResponse.statusCode)")
      throw PlynMacError.serviceError(Self.extractServiceErrorMessage(from: data, statusCode: httpResponse.statusCode))
    }

    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      throw PlynMacError.invalidGeminiResponse
    }

    let transcript = Self.extractTranscript(from: json)
    let tokenUsage = Self.extractTokenUsage(from: json)
    tokenUsageRecorder?.record(tokenUsage)
    PlynMacLogger.log("gemini request succeeded transcriptChars=\(transcript.count)")
    return transcript
  }

  private func makeRequest(
    configuration: PlynMacGeminiConfiguration,
    audioData: Data,
    outputLanguage: PlynMacOutputLanguage
  ) throws -> URLRequest {
    let escapedModel = configuration.model.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? configuration.model
    var components = URLComponents(string: "https://generativelanguage.googleapis.com/v1beta/models/\(escapedModel):generateContent")
    components?.queryItems = [URLQueryItem(name: "key", value: configuration.apiKey)]
    guard let url = components?.url else {
      throw PlynMacError.invalidGeminiEndpoint
    }

    let body: [String: Any] = [
      "system_instruction": [
        "parts": [["text": configuration.systemPrompt]],
      ],
      "contents": [[
        "parts": [
          ["text": PlynMacGeminiPrompt.userInstruction(outputLanguage: outputLanguage)],
          [
            "inlineData": [
              "mimeType": "audio/wav",
              "data": audioData.base64EncodedString(),
            ],
          ],
        ],
      ]],
    ]

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    return request
  }

  static func extractTranscript(from json: [String: Any]?) -> String {
    guard
      let json,
      let candidates = json["candidates"] as? [[String: Any]],
      let content = candidates.first?["content"] as? [String: Any],
      let parts = content["parts"] as? [[String: Any]]
    else {
      return ""
    }

    return parts.compactMap { $0["text"] as? String }.joined()
  }

  public static func extractTokenUsage(from json: [String: Any]?) -> PlynMacTokenUsageSnapshot {
    guard let usage = json?["usageMetadata"] as? [String: Any] else {
      return .empty
    }

    let inputTokens = usage.intValue(for: "promptTokenCount")
    let cachedInputTokens = usage.intValue(for: "cachedContentTokenCount")
    let outputTokens = usage.intValue(for: "candidatesTokenCount")
    let totalTokens = usage.intValue(for: "totalTokenCount")

    return PlynMacTokenUsageSnapshot(
      inputTokens: inputTokens,
      cachedInputTokens: cachedInputTokens,
      outputTokens: outputTokens,
      totalTokens: totalTokens,
      inputByModality: extractModalityBreakdown(
        totalTokens: inputTokens,
        value: usage["promptTokensDetails"],
        fallback: .audio
      ),
      cachedInputByModality: extractModalityBreakdown(
        totalTokens: cachedInputTokens,
        value: usage["cacheTokensDetails"] ?? usage["cachedContentTokenDetails"],
        fallback: .audio
      ),
      outputByModality: extractModalityBreakdown(
        totalTokens: outputTokens,
        value: usage["candidatesTokensDetails"],
        fallback: .text
      )
    )
  }

  enum TokenModality {
    case text
    case audio
  }

  private static func extractModalityBreakdown(
    totalTokens: Int,
    value: Any?,
    fallback: TokenModality
  ) -> PlynMacModalityTokenBreakdown {
    var breakdown = PlynMacModalityTokenBreakdown()
    guard let details = value as? [[String: Any]] else {
      return breakdown.addingRemainder(totalTokens, fallback: fallback)
    }

    for detail in details {
      let tokenCount = detail.intValue(for: "tokenCount")
      let modality = (detail["modality"] as? String ?? "").lowercased()
      switch modality {
      case "text":
        breakdown.text += tokenCount
      case "audio":
        breakdown.audio += tokenCount
      case "image":
        breakdown.image += tokenCount
      case "video":
        breakdown.video += tokenCount
      case "document":
        breakdown.document += tokenCount
      default:
        break
      }
    }

    return breakdown.addingRemainder(totalTokens, fallback: fallback)
  }

  static func extractServiceErrorMessage(from data: Data, statusCode: Int) -> String {
    if
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let error = json["error"] as? [String: Any],
      let message = error["message"] as? String,
      !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    {
      return message
    }

    switch statusCode {
    case 400 ... 499:
      return "Не ўдалося апрацаваць запіс. Праверце налады і паспрабуйце яшчэ раз."
    case 500 ... 599:
      return "Сэрвіс апрацоўкі часова недаступны. Паспрабуйце крыху пазней."
    default:
      return "Падчас апрацоўкі маўлення нешта пайшло не так. Паспрабуйце яшчэ раз."
    }
  }
}

private extension Dictionary where Key == String, Value == Any {
  func intValue(for key: String) -> Int {
    if let value = self[key] as? Int {
      return value
    }
    if let value = self[key] as? Double {
      return Int(value)
    }
    if let value = self[key] as? String, let intValue = Int(value) {
      return intValue
    }
    return 0
  }
}

private extension PlynMacModalityTokenBreakdown {
  func addingRemainder(
    _ totalTokens: Int,
    fallback: PlynMacGeminiTranscriber.TokenModality
  ) -> PlynMacModalityTokenBreakdown {
    let remainder = totalTokens - total
    guard remainder > 0 else {
      return self
    }

    var next = self
    switch fallback {
    case .text:
      next.text += remainder
    case .audio:
      next.audio += remainder
    }
    return next
  }
}
