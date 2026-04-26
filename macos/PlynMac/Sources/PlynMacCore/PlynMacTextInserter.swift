import AppKit
import Foundation

public final class PlynMacPasteboardTextInserter: PlynMacTextInserting, @unchecked Sendable {
  private let pasteboard: NSPasteboard
  private let restoreDelay: TimeInterval

  public init(pasteboard: NSPasteboard = .general, restoreDelay: TimeInterval = 2.0) {
    self.pasteboard = pasteboard
    self.restoreDelay = restoreDelay
  }

  public func insert(_ text: String) async throws {
    let previousItems = savedPasteboardItems()

    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
    try postPasteShortcut()
    PlynMacLogger.log("paste shortcut posted chars=\(text.count)")

    try? await Task.sleep(nanoseconds: UInt64(restoreDelay * 1_000_000_000))
    pasteboard.clearContents()
    if !previousItems.isEmpty {
      pasteboard.writeObjects(previousItems)
    }
  }

  private func savedPasteboardItems() -> [NSPasteboardItem] {
    pasteboard.pasteboardItems?.map { item in
      let copy = NSPasteboardItem()
      for type in item.types {
        if let data = item.data(forType: type) {
          copy.setData(data, forType: type)
        }
      }
      return copy
    } ?? []
  }

  private func postPasteShortcut() throws {
    guard let source = CGEventSource(stateID: .hidSystemState) else {
      throw PlynMacError.serviceError("Keyboard event source is unavailable.")
    }

    let keyCodeForV: CGKeyCode = 9
    let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCodeForV, keyDown: true)
    let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCodeForV, keyDown: false)
    keyDown?.flags = .maskCommand
    keyUp?.flags = .maskCommand
    keyDown?.post(tap: .cghidEventTap)
    keyUp?.post(tap: .cghidEventTap)
  }
}
