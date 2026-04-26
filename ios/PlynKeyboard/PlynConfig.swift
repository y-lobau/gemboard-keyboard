import Foundation
import React

@objc(PlyńAppConfig)
final class PlyńAppConfig: NSObject {
  @objc
  func getStatus(_ resolve: RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) {
    NSLog("[PlyńAppConfig] getStatus requested")
    let hasApiKey = PlyńE2EOverrides.hasApiKey ?? PlynSharedStore.hasApiKey()
    let sessionActive = PlyńE2EOverrides.currentSessionActive(
      fallback: PlynSharedStore.isSessionActive()
    )
    let keyboardRecoveryHandoffPending = PlynSharedStore.consumeKeyboardRecoveryHandoff()

    resolve([
      "hasApiKey": hasApiKey,
      "sessionActive": sessionActive,
      "platformMode": "ios-keyboard-extension",
      "keyboardRecoveryHandoffPending": keyboardRecoveryHandoffPending,
    ])
  }

  @objc
  func saveApiKey(_ apiKey: String, resolver resolve: RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) {
    NSLog("[PlyńAppConfig] saveApiKey requested length=\(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).count)")
    PlynSharedStore.saveApiKey(apiKey)
    resolve(nil)
  }

  @objc
  func saveRuntimeConfig(_ config: NSDictionary, resolver resolve: RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) {
    let model = (config["model"] as? String) ?? ""
    let systemPrompt = (config["systemPrompt"] as? String) ?? ""
    let keyboardCommandTimeout = (config["keyboardCommandTimeout"] as? NSNumber)?.doubleValue
    let keyboardTranscriptionTimeout = (config["keyboardTranscriptionTimeout"] as? NSNumber)?.doubleValue

    PlynSharedStore.saveGeminiModel(model)
    PlynSharedStore.saveGeminiSystemPrompt(systemPrompt)
    if let keyboardCommandTimeout {
      PlynSharedStore.saveKeyboardCommandTimeout(keyboardCommandTimeout)
    }
    if let keyboardTranscriptionTimeout {
      PlynSharedStore.saveKeyboardTranscriptionTimeout(keyboardTranscriptionTimeout)
    }
    resolve(nil)
  }

  @objc
  func getSectionExpansionState(_ resolve: RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) {
    resolve(PlynSharedStore.sectionExpansionState())
  }

  @objc
  func saveSectionExpansionState(_ config: NSDictionary, resolver resolve: RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) {
    PlynSharedStore.saveSectionExpansionState(
      onboardingExpanded: config["onboardingExpanded"] as? Bool,
      setupExpanded: config["setupExpanded"] as? Bool,
      tokenSummaryExpanded: config["tokenSummaryExpanded"] as? Bool
    )
    resolve(nil)
  }

  @objc
  func getLatestTranscriptSnapshot(_ resolve: RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) {
    guard let snapshot = PlynSharedStore.latestTranscriptSnapshot() else {
      resolve(nil)
      return
    }

    resolve([
      "text": snapshot.text,
      "sessionID": snapshot.sessionID,
      "sequence": snapshot.sequence,
      "isFinal": snapshot.isFinal,
      "state": snapshot.state.rawValue,
      "errorCode": snapshot.errorCode as Any,
      "updatedAt": snapshot.updatedAt.timeIntervalSince1970,
    ])
  }

  @objc
  func clearLatestTranscript(_ resolve: RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) {
    PlynSharedStore.clearLatestTranscript()
    resolve(nil)
  }

  @objc
  func consumePendingLaunchURL(_ resolve: RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) {
    resolve(PlynPendingLaunchURLStore.consume())
  }

  @objc
  func consumeKeyboardRecoveryHandoff(_ resolve: RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) {
    resolve(PlynSharedStore.consumeKeyboardRecoveryHandoff())
  }

  @objc
  func getTokenUsageSummary(_ resolve: RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) {
    resolve(PlynSharedStore.tokenUsageSummary().asDictionary())
  }

  @objc
  func resetTokenUsageSummary(_ resolve: RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) {
    PlynSharedStore.resetTokenUsageSummary()
    resolve(nil)
  }

  @objc
  func getDebugSnapshot(_ resolve: RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) {
    resolve(PlynSharedStore.debugSnapshot())
  }

  @objc
  func clearDebugSnapshot(_ resolve: RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) {
    PlynSharedStore.clearDebugSnapshot()
    resolve(nil)
  }

  @objc
  func appendCompanionDebugLog(_ message: String, resolver resolve: RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) {
    PlynSharedStore.appendCompanionDebugLog(message)
    resolve(nil)
  }
}

@objc(PlyńConfig)
final class PlyńConfig: NSObject {
  private let appConfig = PlyńAppConfig()

  @objc
  func getStatus(_ resolve: RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) {
    appConfig.getStatus(resolve, rejecter: reject)
  }

  @objc
  func saveApiKey(_ apiKey: String, resolver resolve: RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) {
    appConfig.saveApiKey(apiKey, resolver: resolve, rejecter: reject)
  }

  @objc
  func saveRuntimeConfig(_ config: NSDictionary, resolver resolve: RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) {
    appConfig.saveRuntimeConfig(config, resolver: resolve, rejecter: reject)
  }

  @objc
  func getSectionExpansionState(_ resolve: RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) {
    appConfig.getSectionExpansionState(resolve, rejecter: reject)
  }

  @objc
  func saveSectionExpansionState(_ config: NSDictionary, resolver resolve: RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) {
    appConfig.saveSectionExpansionState(config, resolver: resolve, rejecter: reject)
  }

  @objc
  func getLatestTranscriptSnapshot(_ resolve: RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) {
    appConfig.getLatestTranscriptSnapshot(resolve, rejecter: reject)
  }

  @objc
  func clearLatestTranscript(_ resolve: RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) {
    appConfig.clearLatestTranscript(resolve, rejecter: reject)
  }

  @objc
  func consumePendingLaunchURL(_ resolve: RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) {
    appConfig.consumePendingLaunchURL(resolve, rejecter: reject)
  }

  @objc
  func consumeKeyboardRecoveryHandoff(_ resolve: RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) {
    appConfig.consumeKeyboardRecoveryHandoff(resolve, rejecter: reject)
  }

  @objc
  func getTokenUsageSummary(_ resolve: RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) {
    appConfig.getTokenUsageSummary(resolve, rejecter: reject)
  }

  @objc
  func resetTokenUsageSummary(_ resolve: RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) {
    appConfig.resetTokenUsageSummary(resolve, rejecter: reject)
  }

  @objc
  func getDebugSnapshot(_ resolve: RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) {
    appConfig.getDebugSnapshot(resolve, rejecter: reject)
  }

  @objc
  func clearDebugSnapshot(_ resolve: RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) {
    appConfig.clearDebugSnapshot(resolve, rejecter: reject)
  }

  @objc
  func appendCompanionDebugLog(_ message: String, resolver resolve: RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) {
    appConfig.appendCompanionDebugLog(message, resolver: resolve, rejecter: reject)
  }
}
