// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SleepApp",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SleepCore", targets: ["SleepCore"]),
        .executable(name: "SleepPreview", targets: ["SleepPreview"])
    ],
    targets: [
        .target(name: "SleepCore"),
        .executableTarget(
            name: "SleepPreview",
            dependencies: ["SleepCore"],
            path: "App",
            exclude: ["Assets.xcassets", "Info.plist", "SleepApp.entitlements", "PrivacyInfo.xcprivacy"],
            swiftSettings: [.define("SLEEPAPP_PREVIEW")]
        ),
        .testTarget(name: "SleepCoreTests", dependencies: ["SleepCore"])
    ]
)
