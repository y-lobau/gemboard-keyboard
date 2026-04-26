import AppKit
import Foundation

public final class PlynMacHotKeyMonitor: @unchecked Sendable {
  public typealias Handler = @Sendable (PlynMacHoldTransition) -> Void

  private let triggerProvider: @Sendable () -> PlynMacHoldTrigger
  private let handler: Handler
  private var eventTap: CFMachPort?
  private var runLoopSource: CFRunLoopSource?
  private var globalFlagsMonitor: Any?
  private var stateMachine: PlynMacHoldTriggerStateMachine

  public init(
    triggerProvider: @escaping @Sendable () -> PlynMacHoldTrigger,
    handler: @escaping Handler
  ) {
    self.triggerProvider = triggerProvider
    self.handler = handler
    stateMachine = PlynMacHoldTriggerStateMachine(trigger: triggerProvider())
  }

  deinit {
    stop()
  }

  public func start() throws {
    guard eventTap == nil else {
      return
    }

    let mask = (1 << CGEventType.flagsChanged.rawValue)
    let refcon = Unmanaged.passUnretained(self).toOpaque()
    guard let tap = CGEvent.tapCreate(
      tap: .cgSessionEventTap,
      place: .headInsertEventTap,
      options: .listenOnly,
      eventsOfInterest: CGEventMask(mask),
      callback: PlynMacHotKeyMonitor.eventCallback,
      userInfo: refcon
    ) else {
      throw PlynMacError.eventTapUnavailable
    }

    eventTap = tap
    let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    runLoopSource = source
    CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)

    globalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
      self?.handle(event.modifierFlags)
    }

    PlynMacLogger.log("hotkey monitor started")
  }

  public func stop() {
    if let eventTap {
      CGEvent.tapEnable(tap: eventTap, enable: false)
    }
    if let runLoopSource {
      CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
    }
    if let globalFlagsMonitor {
      NSEvent.removeMonitor(globalFlagsMonitor)
    }
    runLoopSource = nil
    eventTap = nil
    globalFlagsMonitor = nil
  }

  private func handle(_ event: CGEvent) {
    handle(event.flags)
  }

  private func handle(_ flags: CGEventFlags) {
    let trigger = triggerProvider()
    if stateMachine.trigger != trigger {
      stateMachine = PlynMacHoldTriggerStateMachine(trigger: trigger)
    }

    let isPressed: Bool
    switch trigger {
    case .functionGlobe:
      isPressed = flags.contains(.maskSecondaryFn)
    case .controlOption:
      isPressed = flags.contains(.maskControl) && flags.contains(.maskAlternate)
    }

    let transition = stateMachine.handle(isPressed ? .pressed(trigger) : .released(trigger))
    if transition != .unchanged {
      handler(transition)
    }
  }

  private func handle(_ flags: NSEvent.ModifierFlags) {
    let trigger = triggerProvider()
    if stateMachine.trigger != trigger {
      stateMachine = PlynMacHoldTriggerStateMachine(trigger: trigger)
    }

    let isPressed: Bool
    switch trigger {
    case .functionGlobe:
      isPressed = flags.contains(.function)
    case .controlOption:
      isPressed = flags.contains(.control) && flags.contains(.option)
    }

    let transition = stateMachine.handle(isPressed ? .pressed(trigger) : .released(trigger))
    if transition != .unchanged {
      handler(transition)
    }
  }

  private static let eventCallback: CGEventTapCallBack = { _, type, event, userInfo in
    guard type == .flagsChanged, let userInfo else {
      return Unmanaged.passUnretained(event)
    }

    let monitor = Unmanaged<PlynMacHotKeyMonitor>.fromOpaque(userInfo).takeUnretainedValue()
    monitor.handle(event)
    return Unmanaged.passUnretained(event)
  }
}
