import Foundation
import React

@objc(PlynSession)
final class PlynSession: NSObject {
  @objc
  func getStatus(_ resolve: RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) {
    if PlyńE2EOverrides.isEnabled {
      resolve(["isActive": PlyńE2EOverrides.currentSessionActive(fallback: true)])
      return
    }

    resolve(PlyńSessionManager.shared.getStatus())
  }

  @objc
  func startSession(_ resolve: RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) {
    if PlyńE2EOverrides.isEnabled {
      PlyńE2EOverrides.setSessionActive(true)
      resolve(["isActive": true])
      return
    }

    do {
      let status = try PlyńSessionManager.shared.startSession()
      resolve(status)
    } catch {
      reject("session_start_error", error.localizedDescription, error)
    }
  }

  @objc
  func stopSession(_ resolve: RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) {
    if PlyńE2EOverrides.isEnabled {
      PlyńE2EOverrides.setSessionActive(false)
      resolve(["isActive": false])
      return
    }

    PlyńSessionManager.shared.stopSession()
    resolve(PlyńSessionManager.shared.getStatus())
  }
}
