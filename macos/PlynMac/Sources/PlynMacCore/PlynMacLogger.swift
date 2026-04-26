import Foundation

public enum PlynMacLogger {
  private static let queue = DispatchQueue(label: "com.holas.plynkeyboard.mac.log")

  public static func log(_ message: String) {
    queue.async {
      let timestamp = ISO8601DateFormatter().string(from: Date())
      let line = "[\(timestamp)] \(message)\n"
      NSLog("[PlynMac] \(message)")

      guard let url = logFileURL() else {
        return
      }

      do {
        try FileManager.default.createDirectory(
          at: url.deletingLastPathComponent(),
          withIntermediateDirectories: true
        )
        if FileManager.default.fileExists(atPath: url.path) {
          let handle = try FileHandle(forWritingTo: url)
          try handle.seekToEnd()
          if let data = line.data(using: .utf8) {
            try handle.write(contentsOf: data)
          }
          try handle.close()
        } else {
          try line.write(to: url, atomically: true, encoding: .utf8)
        }
      } catch {
        NSLog("[PlynMac] logWriteFailed error=\(error.localizedDescription)")
      }
    }
  }

  public static func logFileURL() -> URL? {
    let applicationSupportURL = FileManager.default.urls(
      for: .applicationSupportDirectory,
      in: .userDomainMask
    ).first
    return applicationSupportURL?
      .appendingPathComponent("PlynMac", isDirectory: true)
      .appendingPathComponent("debug.log")
  }
}
