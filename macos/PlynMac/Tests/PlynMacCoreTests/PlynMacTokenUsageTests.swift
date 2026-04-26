import Foundation
import XCTest
@testable import PlynMacCore

final class PlynMacTokenUsageTests: XCTestCase {
  func testRecordsLatestTotalAndAverageUsage() throws {
    let fileURL = temporaryStateURL()
    let store = PlynMacLocalStateStore(fileURL: fileURL)
    defer { try? FileManager.default.removeItem(at: fileURL) }
    let recorder = PlynMacTokenUsageStore(store: store)

    recorder.record(PlynMacTokenUsageSnapshot(
      inputTokens: 100,
      cachedInputTokens: 20,
      outputTokens: 30,
      totalTokens: 150,
      inputByModality: PlynMacModalityTokenBreakdown(text: 10, audio: 90),
      cachedInputByModality: PlynMacModalityTokenBreakdown(text: 5, audio: 15),
      outputByModality: PlynMacModalityTokenBreakdown(text: 30)
    ))
    recorder.record(PlynMacTokenUsageSnapshot(
      inputTokens: 50,
      cachedInputTokens: 10,
      outputTokens: 10,
      totalTokens: 70,
      inputByModality: PlynMacModalityTokenBreakdown(text: 20, audio: 30),
      cachedInputByModality: PlynMacModalityTokenBreakdown(text: 10, audio: 0),
      outputByModality: PlynMacModalityTokenBreakdown(text: 10)
    ))

    let summary = recorder.summary

    XCTAssertEqual(summary.requestCount, 2)
    XCTAssertEqual(summary.lastRequest.inputTokens, 50)
    XCTAssertEqual(summary.inputTokens, 150)
    XCTAssertEqual(summary.cachedInputTokens, 30)
    XCTAssertEqual(summary.outputTokens, 40)
    XCTAssertEqual(summary.average.inputTokens, 75)
    XCTAssertEqual(summary.average.inputByModality.audio, 60)
  }

  func testResetClearsUsageSummary() throws {
    let fileURL = temporaryStateURL()
    let store = PlynMacLocalStateStore(fileURL: fileURL)
    defer { try? FileManager.default.removeItem(at: fileURL) }
    let recorder = PlynMacTokenUsageStore(store: store)

    recorder.record(PlynMacTokenUsageSnapshot(
      inputTokens: 1,
      cachedInputTokens: 2,
      outputTokens: 3,
      totalTokens: 6,
      inputByModality: PlynMacModalityTokenBreakdown(audio: 1),
      cachedInputByModality: PlynMacModalityTokenBreakdown(audio: 2),
      outputByModality: PlynMacModalityTokenBreakdown(text: 3)
    ))
    recorder.reset()

    XCTAssertEqual(recorder.summary, .empty)
  }

  func testExtractsUsageMetadataWithModalityRemainders() throws {
    let json: [String: Any] = [
      "usageMetadata": [
        "promptTokenCount": 100,
        "cachedContentTokenCount": 20,
        "candidatesTokenCount": 30,
        "totalTokenCount": 150,
        "promptTokensDetails": [["modality": "TEXT", "tokenCount": 10]],
        "cacheTokensDetails": [["modality": "AUDIO", "tokenCount": 15]],
        "candidatesTokensDetails": [["modality": "TEXT", "tokenCount": 30]],
      ],
    ]

    let snapshot = PlynMacGeminiTranscriber.extractTokenUsage(from: json)

    XCTAssertEqual(snapshot.inputTokens, 100)
    XCTAssertEqual(snapshot.inputByModality.text, 10)
    XCTAssertEqual(snapshot.inputByModality.audio, 90)
    XCTAssertEqual(snapshot.cachedInputByModality.audio, 20)
    XCTAssertEqual(snapshot.outputByModality.text, 30)
  }

  private func temporaryStateURL() -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent("PlynMacTokenUsageTests-")
      .appendingPathExtension(UUID().uuidString)
      .appendingPathExtension("json")
  }
}
