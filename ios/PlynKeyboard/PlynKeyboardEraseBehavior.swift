import Foundation

enum PlynKeyboardEraseBehavior {
  static func deleteCount(for contextBeforeInput: String) -> Int {
    guard !contextBeforeInput.isEmpty else {
      return 0
    }

    if contextBeforeInput.last?.isNewline == true {
      return 1
    }

    var context = contextBeforeInput
    var deleteCount = 0

    while let lastCharacter = context.last, lastCharacter.isWhitespace {
      deleteCount += 1
      context.removeLast()
    }

    while let lastCharacter = context.last, !lastCharacter.isWhitespace {
      deleteCount += 1
      context.removeLast()
    }

    return deleteCount
  }
}
