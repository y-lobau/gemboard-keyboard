import XCTest

final class PlynSharedStoreTranscriptMergeTests: XCTestCase {
  func testTranscriptTextPreservesLeadingWhitespaceFromChunk() {
    let parts: [[String: Any]] = [["text": " world"]]

    XCTAssertEqual(" world", PlynSharedStore.transcriptText(from: parts))
  }

  func testMergeStreamTranscriptPreservesBoundaryWhitespaceWhenFirstChunkEndsWithSpace() {
    let firstChunk = PlynSharedStore.transcriptText(from: [["text": "hello "]])
    let secondChunk = PlynSharedStore.transcriptText(from: [["text": "world"]])

    let merged = PlynSharedStore.mergeStreamTranscript(existing: firstChunk, incoming: secondChunk)

    XCTAssertEqual("hello world", merged)
  }

  func testMergeStreamTranscriptPreservesWhitespaceOnlyChunkBetweenWords() {
    let firstChunk = PlynSharedStore.transcriptText(from: [["text": "hello"]])
    let separatorChunk = PlynSharedStore.transcriptText(from: [["text": " "]])
    let secondChunk = PlynSharedStore.transcriptText(from: [["text": "world"]])

    let merged = PlynSharedStore.mergeStreamTranscript(existing: firstChunk, incoming: separatorChunk)
    let mergedWithWord = PlynSharedStore.mergeStreamTranscript(existing: merged, incoming: secondChunk)

    XCTAssertEqual("hello world", mergedWithWord)
  }
}
