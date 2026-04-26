import AppKit
import AVFoundation
import Foundation

public final class PlynMacPermissionService: ObservableObject, PlynMacPermissionChecking, @unchecked Sendable {
  @Published public private(set) var snapshot: PlynMacPermissionSnapshot

  public init() {
    snapshot = Self.readSnapshot()
  }

  public func currentSnapshot() -> PlynMacPermissionSnapshot {
    Self.readSnapshot()
  }

  @MainActor
  public func refresh() {
    snapshot = Self.readSnapshot()
  }

  @MainActor
  public func requestMicrophone() async {
    _ = await AVCaptureDevice.requestAccess(for: .audio)
    refresh()
  }

  @MainActor
  public func requestInputMonitoring() {
    if #available(macOS 10.15, *) {
      CGRequestListenEventAccess()
    }
    refresh()
  }

  @MainActor
  public func requestAccessibility() {
    PlynMacLogger.log("accessibility permission requested trustedBefore=\(AXIsProcessTrusted())")
    if #available(macOS 10.15, *) {
      CGRequestPostEventAccess()
    }
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
    AXIsProcessTrustedWithOptions(options as CFDictionary)
    refresh()
  }

  @MainActor
  public func openMicrophoneSettings() {
    openPrivacyPane("Privacy_Microphone", fallbackPane: "Privacy_Microphone")
  }

  @MainActor
  public func openInputMonitoringSettings() {
    openPrivacyPane("Privacy_ListenEvent", fallbackPane: "Privacy_ListenEvent")
  }

  @MainActor
  public func openAccessibilitySettings() {
    openPrivacyPane("Privacy_Accessibility", fallbackPane: "Privacy_Accessibility")
  }

  @MainActor
  private func openPrivacyPane(_ pane: String, fallbackPane: String) {
    let candidates = [
      "x-apple.systempreferences:com.apple.preference.security?\(pane)",
      "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?\(fallbackPane)",
      "x-apple.systempreferences:com.apple.preference.security"
    ]

    for candidate in candidates {
      guard let url = URL(string: candidate) else {
        continue
      }

      PlynMacLogger.log("opening settings url=\(candidate)")
      if NSWorkspace.shared.open(url) {
        return
      }
    }

    PlynMacLogger.log("opening settings failed pane=\(pane)")
  }

  private static func readSnapshot() -> PlynMacPermissionSnapshot {
    let microphoneGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    let inputMonitoringGranted: Bool
    if #available(macOS 10.15, *) {
      inputMonitoringGranted = CGPreflightListenEventAccess() || canCreateListenOnlyEventTap()
    } else {
      inputMonitoringGranted = true
    }

    let postEventGranted: Bool
    if #available(macOS 10.15, *) {
      postEventGranted = CGPreflightPostEventAccess() || AXIsProcessTrusted()
    } else {
      postEventGranted = AXIsProcessTrusted()
    }

    return PlynMacPermissionSnapshot(
      microphoneGranted: microphoneGranted,
      inputMonitoringGranted: inputMonitoringGranted,
      accessibilityGranted: postEventGranted
    )
  }

  private static func canCreateListenOnlyEventTap() -> Bool {
    let mask = (1 << CGEventType.flagsChanged.rawValue)
    guard let tap = CGEvent.tapCreate(
      tap: .cgSessionEventTap,
      place: .tailAppendEventTap,
      options: .listenOnly,
      eventsOfInterest: CGEventMask(mask),
      callback: { _, _, event, _ in Unmanaged.passUnretained(event) },
      userInfo: nil
    ) else {
      return false
    }

    CGEvent.tapEnable(tap: tap, enable: false)
    CFMachPortInvalidate(tap)
    return true
  }
}
