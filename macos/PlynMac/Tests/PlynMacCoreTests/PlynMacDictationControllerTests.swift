import Foundation
import XCTest
@testable import PlynMacCore

final class PlynMacDictationControllerTests: XCTestCase {
  func testHoldReleaseRecordsTranscribesAndInserts() async throws {
    let audio = FakeAudioRecorder()
    let transcriber = FakeTranscriber(transcript: "Прывітанне")
    let inserter = FakeTextInserter()
    let controller = PlynMacDictationController(
      audioRecorder: audio,
      transcriber: transcriber,
      textInserter: inserter,
      configuration: FakeConfiguration(isReady: true),
      permissionChecker: FakePermissionChecker(snapshot: .granted)
    )

    await controller.handleHoldStarted()
    await controller.handleHoldEnded()

    XCTAssertEqual(audio.events, ["start", "stop"])
    XCTAssertEqual(transcriber.audioURLs, [audio.outputURL])
    XCTAssertEqual(inserter.insertedTexts, ["Прывітанне"])
    let state = await controller.currentState()
    XCTAssertEqual(state, .idle)
  }

  func testTranscriptionRemovesInvisibleControlAndFormattingCharacters() async {
    let inserter = FakeTextInserter()
    let controller = PlynMacDictationController(
      audioRecorder: FakeAudioRecorder(),
      transcriber: FakeTranscriber(transcript: "Пры\u{0000}ві\u{200B}танне\nз\tтабам"),
      textInserter: inserter,
      configuration: FakeConfiguration(isReady: true),
      permissionChecker: FakePermissionChecker(snapshot: .granted)
    )

    await controller.handleHoldStarted()
    await controller.handleHoldEnded()

    XCTAssertEqual(inserter.insertedTexts, ["Прывітанне\nз\tтабам"])
    let transcript = await controller.currentTranscript()
    XCTAssertEqual(transcript, "Прывітанне\nз\tтабам")
  }

  func testTranscriptionFailureRemovesProcessingIndicator() async {
    let inserter = FakeTextInserter()
    let controller = PlynMacDictationController(
      audioRecorder: FakeAudioRecorder(),
      transcriber: FakeTranscriber(error: TestError.transcriptionFailed),
      textInserter: inserter,
      configuration: FakeConfiguration(isReady: true),
      permissionChecker: FakePermissionChecker(snapshot: .granted)
    )

    await controller.handleHoldStarted()
    await controller.handleHoldEnded()

    XCTAssertTrue(inserter.insertedTexts.isEmpty)
    let state = await controller.currentState()
    XCTAssertEqual(state, .failed("Transcription failed."))
  }

  func testMissingPermissionBlocksRecording() async {
    let audio = FakeAudioRecorder()
    let controller = PlynMacDictationController(
      audioRecorder: audio,
      transcriber: FakeTranscriber(transcript: ""),
      textInserter: FakeTextInserter(),
      configuration: FakeConfiguration(isReady: true),
      permissionChecker: FakePermissionChecker(snapshot: PlynMacPermissionSnapshot(
        microphoneGranted: true,
        inputMonitoringGranted: false,
        accessibilityGranted: true
      ))
    )

    await controller.handleHoldStarted()

    XCTAssertTrue(audio.events.isEmpty)
    let state = await controller.currentState()
    XCTAssertEqual(state, .failed("Input Monitoring permission is required."))
  }

  func testMissingConfigurationBlocksRecording() async {
    let audio = FakeAudioRecorder()
    let controller = PlynMacDictationController(
      audioRecorder: audio,
      transcriber: FakeTranscriber(transcript: ""),
      textInserter: FakeTextInserter(),
      configuration: FakeConfiguration(isReady: false),
      permissionChecker: FakePermissionChecker(snapshot: .granted)
    )

    await controller.handleHoldStarted()

    XCTAssertTrue(audio.events.isEmpty)
    let state = await controller.currentState()
    XCTAssertEqual(state, .failed("Save the Gemini setup before dictating."))
  }

  func testEmptyTranscriptRemovesProcessingIndicator() async {
    let inserter = FakeTextInserter()
    let controller = PlynMacDictationController(
      audioRecorder: FakeAudioRecorder(),
      transcriber: FakeTranscriber(transcript: "   "),
      textInserter: inserter,
      configuration: FakeConfiguration(isReady: true),
      permissionChecker: FakePermissionChecker(snapshot: .granted)
    )

    await controller.handleHoldStarted()
    await controller.handleHoldEnded()

    XCTAssertTrue(inserter.insertedTexts.isEmpty)
    let state = await controller.currentState()
    XCTAssertEqual(state, .failed("Gemini returned an empty transcript."))
  }
}

private enum TestError: LocalizedError {
  case transcriptionFailed

  var errorDescription: String? {
    "Transcription failed."
  }
}

private final class FakeAudioRecorder: PlynMacAudioRecording, @unchecked Sendable {
  let outputURL = URL(fileURLWithPath: "/tmp/plyn-test.wav")
  private(set) var events: [String] = []

  func startRecording() async throws {
    events.append("start")
  }

  func stopRecording() async throws -> URL {
    events.append("stop")
    return outputURL
  }
}

private final class FakeTranscriber: PlynMacTranscribing, @unchecked Sendable {
  private let transcript: String
  private let error: Error?
  private(set) var audioURLs: [URL] = []

  init(transcript: String = "", error: Error? = nil) {
    self.transcript = transcript
    self.error = error
  }

  func transcribe(audioURL: URL) async throws -> String {
    audioURLs.append(audioURL)
    if let error {
      throw error
    }
    return transcript
  }
}

private final class FakeTextInserter: PlynMacTextInserting, @unchecked Sendable {
  private(set) var insertedTexts: [String] = []

  func insert(_ text: String) async throws {
    insertedTexts.append(text)
  }
}

private struct FakeConfiguration: PlynMacConfigurationProviding {
  let isReady: Bool
}

private struct FakePermissionChecker: PlynMacPermissionChecking {
  let snapshot: PlynMacPermissionSnapshot

  func currentSnapshot() -> PlynMacPermissionSnapshot {
    snapshot
  }
}
