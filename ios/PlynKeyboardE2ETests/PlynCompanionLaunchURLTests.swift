import XCTest

final class PlynCompanionLaunchURLTests: XCTestCase {
  func testRecognizesCompanionSchemeAsHandled() {
    XCTAssertTrue(PlynCompanionLaunchURL.isCompanionURL(URL(string: "plyn://")!))
    XCTAssertTrue(PlynCompanionLaunchURL.isCompanionURL(URL(string: "PLYN://session")!))
  }

  func testIgnoresNonCompanionSchemes() {
    XCTAssertFalse(PlynCompanionLaunchURL.isCompanionURL(URL(string: "https://holas.app")!))
  }

  func testRecognizesSessionRecoveryURL() {
    XCTAssertTrue(PlynCompanionLaunchURL.shouldRestoreSession(for: URL(string: "plyn://session")!))
  }

  func testIgnoresNonSessionCompanionURLForRecovery() {
    XCTAssertFalse(PlynCompanionLaunchURL.shouldRestoreSession(for: URL(string: "plyn://settings")!))
  }
}
