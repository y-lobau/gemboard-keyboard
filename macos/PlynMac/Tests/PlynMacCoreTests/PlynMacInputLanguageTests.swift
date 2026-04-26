import XCTest
@testable import PlynMacCore

final class PlynMacInputLanguageTests: XCTestCase {
  func testEnglishInputSourceRequestsEnglishOutput() {
    let language = PlynMacInputLanguageResolver.outputLanguage(for: ["en-US"])

    XCTAssertEqual(language.identifier, "en-US")
    XCTAssertEqual(language.displayName, "English")
  }

  func testBelarusianInputSourceRequestsBelarusianOutput() {
    let language = PlynMacInputLanguageResolver.outputLanguage(for: ["be"])

    XCTAssertEqual(language.identifier, "be")
    XCTAssertEqual(language.displayName, "Belarusian")
  }

  func testMissingInputSourceFallsBackToBelarusian() {
    let language = PlynMacInputLanguageResolver.outputLanguage(for: [])

    XCTAssertEqual(language, .belarusian)
  }

  func testUserInstructionUsesActiveKeyboardLanguage() {
    let instruction = PlynMacGeminiPrompt.userInstruction(outputLanguage: PlynMacOutputLanguage(
      identifier: "en-US",
      displayName: "English"
    ))

    XCTAssertTrue(instruction.contains("Return only English transcript text."))
    XCTAssertTrue(instruction.contains("If the speech is in another language, translate it into English."))
  }

  func testSystemInstructionIsLanguageNeutral() {
    let instruction = PlynMacGeminiPrompt.systemInstruction

    XCTAssertTrue(instruction.contains("speech-to-text dictation engine"))
    XCTAssertFalse(instruction.contains("Belarusian"))
    XCTAssertFalse(instruction.contains("English"))
  }
}
