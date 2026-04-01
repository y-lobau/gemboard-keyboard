import Foundation
import React

@objc(GemboardConfig)
final class GemboardConfig: NSObject {
  private let apiKeyKey = "gemini_api_key"

  @objc
  func getStatus(_ resolve: RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) {
    let apiKey = UserDefaults.standard.string(forKey: apiKeyKey)
    resolve([
      "hasApiKey": !(apiKey?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true),
      "platformMode": "ios-accessory",
    ])
  }

  @objc
  func saveApiKey(_ apiKey: String, resolver resolve: RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) {
    UserDefaults.standard.set(apiKey.trimmingCharacters(in: .whitespacesAndNewlines), forKey: apiKeyKey)
    resolve(nil)
  }
}
