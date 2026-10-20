// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Sweepdeck",
    platforms: [.macOS("15.0")],
    products: [.executable(name: "Sweepdeck", targets: ["Sweepdeck"])],
    targets: [
        .target(name: "SweepdeckCore"),
        .target(name: "SweepdeckAppearance", dependencies: ["SweepdeckCore"]),
        .executableTarget(name: "Sweepdeck", dependencies: ["SweepdeckCore", "SweepdeckAppearance"]),
        .testTarget(name: "SweepdeckCoreTests", dependencies: ["SweepdeckCore"]),
        .testTarget(name: "SweepdeckAppearanceTests", dependencies: ["SweepdeckAppearance", "SweepdeckCore"])
    ]
)
