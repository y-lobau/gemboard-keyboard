import XCTest

final class PlynKeyboardEraseBehaviorTests: XCTestCase {
  func testReturnsZeroForEmptyContext() {
    XCTAssertEqual(PlynKeyboardEraseBehavior.deleteCount(for: ""), 0)
  }

  func testDeletesSingleNewlineBoundaryAtStartOfEmptyLine() {
    XCTAssertEqual(PlynKeyboardEraseBehavior.deleteCount(for: "hello\n"), 1)
  }

  func testDeletesTrailingWhitespaceAndPreviousWordAsSingleEraseAction() {
    XCTAssertEqual(PlynKeyboardEraseBehavior.deleteCount(for: "hello   "), 8)
  }

  func testDeletesPreviousWordWithoutCrossingEarlierWhitespaceBoundary() {
    XCTAssertEqual(PlynKeyboardEraseBehavior.deleteCount(for: "hello brave"), 5)
  }
}
