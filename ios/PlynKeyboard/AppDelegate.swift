import FirebaseCore
import UIKit
import React
import React_RCTAppDelegate
import ReactAppDependencyProvider

enum PlynPendingLaunchURLStore {
  private static var pendingLaunchURL: String?

  static func save(_ url: URL) {
    pendingLaunchURL = url.absoluteString
  }

  static func consume() -> String? {
    defer {
      pendingLaunchURL = nil
    }

    return pendingLaunchURL
  }
}

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
  var window: UIWindow?

  var reactNativeDelegate: ReactNativeDelegate?
  var reactNativeFactory: RCTReactNativeFactory?
  private var initialLaunchURL: URL?

  private func makeInitialProps() -> [String: Any] {
    let hasApiKey = PlyńE2EOverrides.hasApiKey ?? PlynSharedStore.hasApiKey()
    let sessionActive = PlyńE2EOverrides.currentSessionActive(
      fallback: PlynSharedStore.isSessionActive()
    )
    let initialKeyboardRecoveryHandoff = PlynSharedStore.hasRecentKeyboardRecoveryHandoff()

    return [
      "initialHasApiKey": hasApiKey,
      "initialSessionActive": sessionActive,
      "initialPlatformMode": "ios-keyboard-extension",
      "initialLaunchURL": initialLaunchURL?.absoluteString as Any,
      "initialKeyboardRecoveryHandoff": initialKeyboardRecoveryHandoff,
    ]
  }

  private func startCompanionSessionIfNeeded() {
    guard PlynSharedStore.hasApiKey() else {
      return
    }

    let status = PlyńSessionManager.shared.getStatus()
    guard (status["isActive"] as? Bool) != true else {
      PlynSharedStore.refreshSessionHeartbeat()
      NSLog("[AppDelegate] refreshed companion heartbeat during app lifecycle")
      return
    }

    do {
      _ = try PlyńSessionManager.shared.startSession()
      NSLog("[AppDelegate] companion session started during app lifecycle")
    } catch {
      NSLog("[AppDelegate] failed to start companion session: \(error.localizedDescription)")
    }
  }

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    if let launchURL = launchOptions?[.url] as? URL {
      initialLaunchURL = launchURL
      PlynPendingLaunchURLStore.save(launchURL)
    }

    if FirebaseApp.app() == nil {
      FirebaseApp.configure()
    }

    PlyńSessionManager.shared.configure()
    startCompanionSessionIfNeeded()

    let delegate = ReactNativeDelegate()
    let factory = RCTReactNativeFactory(delegate: delegate)
    delegate.dependencyProvider = RCTAppDependencyProvider()

    reactNativeDelegate = delegate
    reactNativeFactory = factory

    window = UIWindow(frame: UIScreen.main.bounds)

    factory.startReactNative(
      withModuleName: "PlynKeyboard",
      in: window,
      initialProperties: makeInitialProps(),
      launchOptions: launchOptions
    )

    return true
  }

  func applicationDidBecomeActive(_ application: UIApplication) {
    startCompanionSessionIfNeeded()
  }

  func applicationWillEnterForeground(_ application: UIApplication) {
    startCompanionSessionIfNeeded()
  }

  func applicationWillTerminate(_ application: UIApplication) {
    PlyńSessionManager.shared.stopSession()
  }

  func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    initialLaunchURL = url
    PlynPendingLaunchURLStore.save(url)

    if url.scheme == "plyn", url.host == "session" {
      startCompanionSessionIfNeeded()
    }

    return RCTLinkingManager.application(app, open: url, options: options)
  }
}

class ReactNativeDelegate: RCTDefaultReactNativeFactoryDelegate {
  override func sourceURL(for bridge: RCTBridge) -> URL? {
    self.bundleURL()
  }

  override func bundleURL() -> URL? {
#if DEBUG
    if let bundleURL = RCTBundleURLProvider.sharedSettings().jsBundleURL(forBundleRoot: "index") {
      return bundleURL
    }

    return URL(string: "http://127.0.0.1:8082/index.bundle?platform=ios&dev=true&minify=false")
#else
    Bundle.main.url(forResource: "main", withExtension: "jsbundle")
#endif
  }
}
