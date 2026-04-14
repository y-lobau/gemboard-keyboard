import FirebaseCore
import UIKit
import React
import React_RCTAppDelegate
import ReactAppDependencyProvider

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
  var window: UIWindow?

  var reactNativeDelegate: ReactNativeDelegate?
  var reactNativeFactory: RCTReactNativeFactory?

  private func makeInitialProps() -> [String: Any] {
    let hasApiKey = PlyńE2EOverrides.hasApiKey ?? PlynSharedStore.hasApiKey()
    let sessionActive = PlyńE2EOverrides.currentSessionActive(
      fallback: PlynSharedStore.isSessionActive()
    )

    return [
      "initialHasApiKey": hasApiKey,
      "initialSessionActive": sessionActive,
      "initialPlatformMode": "ios-keyboard-extension",
    ]
  }

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    PlynSharedStore.appendCompanionDebugLog("application didFinishLaunching")
    if FirebaseApp.app() == nil {
      FirebaseApp.configure()
      PlynSharedStore.appendCompanionDebugLog("firebase configured during launch")
    }

    PlyńSessionManager.shared.configure()
    PlynSharedStore.appendCompanionDebugLog("session manager configured during launch")

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
    PlynSharedStore.appendCompanionDebugLog("applicationDidBecomeActive")
  }

  func applicationWillEnterForeground(_ application: UIApplication) {
    PlynSharedStore.appendCompanionDebugLog("applicationWillEnterForeground")
    PlyńSessionManager.shared.pauseSessionUntilKeyboardVisible()
    PlynSharedStore.appendCompanionDebugLog("paused companion session while app is foregrounded")
  }

  func applicationWillTerminate(_ application: UIApplication) {
    PlyńSessionManager.shared.stopSession()
  }

  func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    PlynSharedStore.appendCompanionDebugLog("application open url=\(url.absoluteString)")
    if PlynCompanionLaunchURL.shouldRestoreSession(for: url) {
      PlynSharedStore.markSessionRecoveryAttempt()
      PlynSharedStore.appendCompanionDebugLog("handling session recovery deep link while keeping foreground audio inactive")
    }

    let handledByReact = RCTLinkingManager.application(app, open: url, options: options)
    return PlynCompanionLaunchURL.isCompanionURL(url) || handledByReact
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
