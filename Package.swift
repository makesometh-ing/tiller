// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Tiller",
    platforms: [.macOS("26.0")],
    targets: [
        .target(name: "TillerCore"),
        .executableTarget(
            name: "Tiller",
            dependencies: ["TillerCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(name: "TillerTestWindows", swiftSettings: [.swiftLanguageMode(.v5)]),
        .executableTarget(name: "tiller-proof", dependencies: ["TillerCore"], swiftSettings: [.swiftLanguageMode(.v5)]),
        .testTarget(name: "TillerCoreTests", dependencies: ["TillerCore"]),
    ]
)
