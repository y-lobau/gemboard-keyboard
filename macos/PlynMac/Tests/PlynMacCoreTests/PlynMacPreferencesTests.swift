import Foundation
import XCTest
@testable import PlynMacCore

final class PlynMacPreferencesTests: XCTestCase {
  func testAPIKeyPersistsAcrossPreferenceInstances() throws {
    let fileURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlynMacPreferencesTests-")
      .appendingPathExtension(UUID().uuidString)
      .appendingPathExtension("json")
    defer { try? FileManager.default.removeItem(at: fileURL) }

    let firstPreferences = PlynMacPreferences(store: PlynMacLocalStateStore(fileURL: fileURL))
    try firstPreferences.saveAPIKey("test-key")

    let secondPreferences = PlynMacPreferences(store: PlynMacLocalStateStore(fileURL: fileURL))

    XCTAssertTrue(secondPreferences.hasSavedAPIKey)
    XCTAssertEqual(try secondPreferences.geminiConfiguration().apiKey, "test-key")
  }

  func testModelDefaultsToGemini25FlashAndPersistsSelection() throws {
    let fileURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlynMacPreferencesModelTests-")
      .appendingPathExtension(UUID().uuidString)
      .appendingPathExtension("json")
    defer { try? FileManager.default.removeItem(at: fileURL) }

    let firstPreferences = PlynMacPreferences(store: PlynMacLocalStateStore(fileURL: fileURL))
    XCTAssertEqual(firstPreferences.model, PlynMacGeminiModel.gemini25Flash.rawValue)

    firstPreferences.model = PlynMacGeminiModel.gemini3FlashPreview.rawValue
    let secondPreferences = PlynMacPreferences(store: PlynMacLocalStateStore(fileURL: fileURL))

    XCTAssertEqual(secondPreferences.model, PlynMacGeminiModel.gemini3FlashPreview.rawValue)
  }

  func testGeminiSystemPromptUsesStoredRemotePromptWithLocalFallback() throws {
    let fileURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlynMacPreferencesPromptTests-")
      .appendingPathExtension(UUID().uuidString)
      .appendingPathExtension("json")
    defer { try? FileManager.default.removeItem(at: fileURL) }

    let preferences = PlynMacPreferences(store: PlynMacLocalStateStore(fileURL: fileURL))
    XCTAssertEqual(preferences.geminiSystemPrompt(), PlynMacGeminiPrompt.systemInstruction)

    preferences.saveGeminiSystemPrompt(" Remote prompt ")
    XCTAssertEqual(preferences.geminiSystemPrompt(), "Remote prompt")
  }
}
