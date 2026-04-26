import Foundation

public final class PlynMacPreferences: ObservableObject, PlynMacConfigurationProviding, PlynMacGeminiConfigurationProviding, @unchecked Sendable {
  private static let legacySuiteName = "com.holas.plynkeyboard.mac"

  private enum Key {
    static let apiKey = "geminiAPIKey"
    static let model = "geminiModel"
    static let systemPrompt = "geminiSystemPrompt"
    static let holdTrigger = "holdTrigger"
  }

  private let store: PlynMacLocalStateStore

  @Published public var model: String {
    didSet { store.set(model, forKey: Key.model) }
  }

  @Published public var holdTrigger: PlynMacHoldTrigger {
    didSet { store.set(holdTrigger.rawValue, forKey: Key.holdTrigger) }
  }

  @Published public private(set) var hasSavedAPIKey: Bool

  public init(store: PlynMacLocalStateStore = PlynMacLocalStateStore()) {
    self.store = store
    Self.migrateLegacyDefaultsIfNeeded(into: store)
    let storedModel = store.string(forKey: Key.model) ?? ""
    model = PlynMacGeminiModel(rawValue: storedModel)?.rawValue ?? PlynMacGeminiModel.gemini25Flash.rawValue
    holdTrigger = PlynMacHoldTrigger(rawValue: store.string(forKey: Key.holdTrigger) ?? "") ?? .functionGlobe
    hasSavedAPIKey = store.string(forKey: Key.apiKey)?.isEmpty == false
  }

  public func refreshSavedKeyState() {
    hasSavedAPIKey = store.string(forKey: Key.apiKey)?.isEmpty == false
  }

  public var isReady: Bool {
    hasSavedAPIKey &&
      !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  public func saveAPIKey(_ apiKey: String) throws {
    let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedKey.isEmpty else {
      throw PlynMacError.missingConfiguration
    }

    store.set(trimmedKey, forKey: Key.apiKey)
    refreshSavedKeyState()
    guard hasSavedAPIKey else {
      throw PlynMacError.serviceError("Gemini API key could not be saved.")
    }
  }

  public func geminiConfiguration() throws -> PlynMacGeminiConfiguration {
    guard let apiKey = store.string(forKey: Key.apiKey), !apiKey.isEmpty else {
      throw PlynMacError.missingConfiguration
    }
    return PlynMacGeminiConfiguration(
      apiKey: apiKey,
      model: model,
      systemPrompt: geminiSystemPrompt()
    )
  }

  public func saveGeminiSystemPrompt(_ systemPrompt: String) {
    let trimmedPrompt = systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedPrompt.isEmpty else {
      return
    }
    store.set(trimmedPrompt, forKey: Key.systemPrompt)
  }

  public func geminiSystemPrompt() -> String {
    let storedPrompt = store.string(forKey: Key.systemPrompt)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return storedPrompt.isEmpty ? PlynMacGeminiPrompt.systemInstruction : storedPrompt
  }

  private static func migrateLegacyDefaultsIfNeeded(into store: PlynMacLocalStateStore) {
    guard store.string(forKey: Key.apiKey) == nil else {
      return
    }

    let legacyDefaults = UserDefaults(suiteName: legacySuiteName)
    let standardDefaults = UserDefaults.standard
    for key in [Key.apiKey, Key.model, Key.holdTrigger] {
      if let value = legacyDefaults?.string(forKey: key) ?? standardDefaults.string(forKey: key) {
        store.set(value, forKey: key)
      }
    }
  }
}

public final class PlynMacLocalStateStore: @unchecked Sendable {
  private let fileURL: URL
  private let queue = DispatchQueue(label: "com.holas.plynkeyboard.mac.state")

  public init(fileURL: URL? = nil) {
    if let fileURL {
      self.fileURL = fileURL
    } else {
      let applicationSupportURL = FileManager.default.urls(
        for: .applicationSupportDirectory,
        in: .userDomainMask
      ).first ?? FileManager.default.temporaryDirectory
      let baseURL = applicationSupportURL.appendingPathComponent("PlynMac", isDirectory: true)
      self.fileURL = baseURL.appendingPathComponent("state.json")
    }
  }

  public func string(forKey key: String) -> String? {
    queue.sync { readState()[key] }
  }

  public func set(_ value: String, forKey key: String) {
    queue.sync {
      var state = readState()
      state[key] = value
      writeState(state)
    }
  }

  private func readState() -> [String: String] {
    guard
      let data = try? Data(contentsOf: fileURL),
      let state = try? JSONDecoder().decode([String: String].self, from: data)
    else {
      return [:]
    }
    return state
  }

  private func writeState(_ state: [String: String]) {
    do {
      try FileManager.default.createDirectory(
        at: fileURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      let data = try JSONEncoder().encode(state)
      try data.write(to: fileURL, options: [.atomic])
    } catch {
      NSLog("[PlynMac] stateWriteFailed error=\(error.localizedDescription)")
    }
  }
}
