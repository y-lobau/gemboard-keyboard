// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "PlynMac",
  platforms: [
    .macOS(.v13),
  ],
  products: [
    .library(name: "PlynMacCore", targets: ["PlynMacCore"]),
    .executable(name: "PlynMac", targets: ["PlynMacApp"]),
  ],
  dependencies: [
    .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "11.0.0"),
  ],
  targets: [
    .target(name: "PlynMacCore"),
    .executableTarget(
      name: "PlynMacApp",
      dependencies: [
        "PlynMacCore",
        .product(name: "FirebaseCore", package: "firebase-ios-sdk"),
        .product(name: "FirebaseRemoteConfig", package: "firebase-ios-sdk"),
      ]
    ),
    .testTarget(
      name: "PlynMacCoreTests",
      dependencies: ["PlynMacCore"]
    ),
  ]
)
