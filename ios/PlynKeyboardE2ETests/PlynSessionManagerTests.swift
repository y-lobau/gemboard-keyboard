import XCTest

final class PlynSessionManagerTests: XCTestCase {
  func testAcceptsValidAudioInputFormat() {
    XCTAssertTrue(PlynAudioInputFormat.isValidRecordingFormat(sampleRate: 16_000, channelCount: 1))
    XCTAssertTrue(PlynAudioInputFormat.isValidRecordingFormat(sampleRate: 44_100, channelCount: 2))
  }

  func testRejectsInvalidAudioInputFormat() {
    XCTAssertFalse(PlynAudioInputFormat.isValidRecordingFormat(sampleRate: 0, channelCount: 1))
    XCTAssertFalse(PlynAudioInputFormat.isValidRecordingFormat(sampleRate: 16_000, channelCount: 0))
    XCTAssertFalse(PlynAudioInputFormat.isValidRecordingFormat(sampleRate: -1, channelCount: 1))
  }
}
