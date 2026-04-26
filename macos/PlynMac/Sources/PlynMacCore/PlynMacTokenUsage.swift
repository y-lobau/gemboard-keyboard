import Foundation

public struct PlynMacModalityTokenBreakdown: Codable, Equatable, Sendable {
  public var text: Int
  public var audio: Int
  public var image: Int
  public var video: Int
  public var document: Int

  public init(text: Int = 0, audio: Int = 0, image: Int = 0, video: Int = 0, document: Int = 0) {
    self.text = text
    self.audio = audio
    self.image = image
    self.video = video
    self.document = document
  }

  public static let empty = PlynMacModalityTokenBreakdown()

  var total: Int { text + audio + image + video + document }

  func adding(_ other: PlynMacModalityTokenBreakdown) -> PlynMacModalityTokenBreakdown {
    PlynMacModalityTokenBreakdown(
      text: text + other.text,
      audio: audio + other.audio,
      image: image + other.image,
      video: video + other.video,
      document: document + other.document
    )
  }

  func divided(by divisor: Int) -> PlynMacModalityTokenBreakdown {
    guard divisor > 0 else { return .empty }
    return PlynMacModalityTokenBreakdown(
      text: text / divisor,
      audio: audio / divisor,
      image: image / divisor,
      video: video / divisor,
      document: document / divisor
    )
  }
}

public struct PlynMacTokenUsageSnapshot: Codable, Equatable, Sendable {
  public var inputTokens: Int
  public var cachedInputTokens: Int
  public var outputTokens: Int
  public var totalTokens: Int
  public var inputByModality: PlynMacModalityTokenBreakdown
  public var cachedInputByModality: PlynMacModalityTokenBreakdown
  public var outputByModality: PlynMacModalityTokenBreakdown

  public init(
    inputTokens: Int = 0,
    cachedInputTokens: Int = 0,
    outputTokens: Int = 0,
    totalTokens: Int = 0,
    inputByModality: PlynMacModalityTokenBreakdown = .empty,
    cachedInputByModality: PlynMacModalityTokenBreakdown = .empty,
    outputByModality: PlynMacModalityTokenBreakdown = .empty
  ) {
    self.inputTokens = inputTokens
    self.cachedInputTokens = cachedInputTokens
    self.outputTokens = outputTokens
    self.totalTokens = totalTokens
    self.inputByModality = inputByModality
    self.cachedInputByModality = cachedInputByModality
    self.outputByModality = outputByModality
  }

  public static let empty = PlynMacTokenUsageSnapshot()

  func adding(_ other: PlynMacTokenUsageSnapshot) -> PlynMacTokenUsageSnapshot {
    PlynMacTokenUsageSnapshot(
      inputTokens: inputTokens + other.inputTokens,
      cachedInputTokens: cachedInputTokens + other.cachedInputTokens,
      outputTokens: outputTokens + other.outputTokens,
      totalTokens: totalTokens + other.totalTokens,
      inputByModality: inputByModality.adding(other.inputByModality),
      cachedInputByModality: cachedInputByModality.adding(other.cachedInputByModality),
      outputByModality: outputByModality.adding(other.outputByModality)
    )
  }

  func divided(by divisor: Int) -> PlynMacTokenUsageSnapshot {
    guard divisor > 0 else { return .empty }
    return PlynMacTokenUsageSnapshot(
      inputTokens: inputTokens / divisor,
      cachedInputTokens: cachedInputTokens / divisor,
      outputTokens: outputTokens / divisor,
      totalTokens: totalTokens / divisor,
      inputByModality: inputByModality.divided(by: divisor),
      cachedInputByModality: cachedInputByModality.divided(by: divisor),
      outputByModality: outputByModality.divided(by: divisor)
    )
  }
}

public struct PlynMacTokenUsageSummary: Codable, Equatable, Sendable {
  public var inputTokens: Int
  public var cachedInputTokens: Int
  public var outputTokens: Int
  public var totalTokens: Int
  public var requestCount: Int
  public var lastRequest: PlynMacTokenUsageSnapshot
  public var inputByModality: PlynMacModalityTokenBreakdown
  public var cachedInputByModality: PlynMacModalityTokenBreakdown
  public var outputByModality: PlynMacModalityTokenBreakdown

  public init(
    inputTokens: Int = 0,
    cachedInputTokens: Int = 0,
    outputTokens: Int = 0,
    totalTokens: Int = 0,
    requestCount: Int = 0,
    lastRequest: PlynMacTokenUsageSnapshot = .empty,
    inputByModality: PlynMacModalityTokenBreakdown = .empty,
    cachedInputByModality: PlynMacModalityTokenBreakdown = .empty,
    outputByModality: PlynMacModalityTokenBreakdown = .empty
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

  public static let empty = PlynMacTokenUsageSummary()

  public var average: PlynMacTokenUsageSnapshot {
    PlynMacTokenUsageSnapshot(
      inputTokens: inputTokens,
      cachedInputTokens: cachedInputTokens,
      outputTokens: outputTokens,
      totalTokens: totalTokens,
      inputByModality: inputByModality,
      cachedInputByModality: cachedInputByModality,
      outputByModality: outputByModality
    ).divided(by: requestCount)
  }

  func recording(_ snapshot: PlynMacTokenUsageSnapshot) -> PlynMacTokenUsageSummary {
    let total = PlynMacTokenUsageSnapshot(
      inputTokens: inputTokens,
      cachedInputTokens: cachedInputTokens,
      outputTokens: outputTokens,
      totalTokens: totalTokens,
      inputByModality: inputByModality,
      cachedInputByModality: cachedInputByModality,
      outputByModality: outputByModality
    ).adding(snapshot)

    return PlynMacTokenUsageSummary(
      inputTokens: total.inputTokens,
      cachedInputTokens: total.cachedInputTokens,
      outputTokens: total.outputTokens,
      totalTokens: total.totalTokens,
      requestCount: requestCount + 1,
      lastRequest: snapshot,
      inputByModality: total.inputByModality,
      cachedInputByModality: total.cachedInputByModality,
      outputByModality: total.outputByModality
    )
  }
}

public final class PlynMacTokenUsageStore: ObservableObject, @unchecked Sendable {
  private static let key = "tokenUsageSummary"
  private let store: PlynMacLocalStateStore

  @Published public private(set) var summary: PlynMacTokenUsageSummary

  public init(store: PlynMacLocalStateStore = PlynMacLocalStateStore()) {
    self.store = store
    summary = Self.loadSummary(from: store)
  }

  public func record(_ snapshot: PlynMacTokenUsageSnapshot) {
    summary = summary.recording(snapshot)
    persist()
  }

  public func reset() {
    summary = .empty
    persist()
  }

  private func persist() {
    guard let data = try? JSONEncoder().encode(summary),
          let json = String(data: data, encoding: .utf8)
    else {
      return
    }
    store.set(json, forKey: Self.key)
  }

  private static func loadSummary(from store: PlynMacLocalStateStore) -> PlynMacTokenUsageSummary {
    guard let json = store.string(forKey: key),
          let data = json.data(using: .utf8),
          let summary = try? JSONDecoder().decode(PlynMacTokenUsageSummary.self, from: data)
    else {
      return .empty
    }
    return summary
  }
}

public protocol PlynMacTokenUsageRecording: Sendable {
  func record(_ snapshot: PlynMacTokenUsageSnapshot)
}

extension PlynMacTokenUsageStore: PlynMacTokenUsageRecording {}

