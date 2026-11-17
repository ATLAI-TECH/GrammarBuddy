// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GrammarBuddyKit",
    defaultLocalization: "en",
    platforms: [.macOS(.v15)],
    products: [.library(name: "GrammarBuddyKit", targets: ["GrammarBuddyKit"])],
    targets: [
        .target(name: "GrammarBuddyKit", resources: [.copy("Engine/Prompts")],
                swiftSettings: [.swiftLanguageMode(.v5)]),
        .testTarget(name: "GrammarBuddyKitTests", dependencies: ["GrammarBuddyKit"],
                    swiftSettings: [.swiftLanguageMode(.v5)]),
    ]
)
