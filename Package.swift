// swift-tools-version: 6.2
import PackageDescription

let packageRoot = String(#filePath.dropLast("Package.swift".count))
let rustLibraryDirectory = "\(packageRoot).build/rust/release"

let package = Package(
    name: "Sweepdeck",
    platforms: [.macOS("15.0")],
    products: [.executable(name: "Sweepdeck", targets: ["Sweepdeck"])],
    targets: [
        .systemLibrary(name: "SweepdeckRust", path: "Sources/SweepdeckRust"),
        .target(
            name: "SweepdeckCore",
            dependencies: ["SweepdeckRust"],
            linkerSettings: [
                .unsafeFlags(["-L\(rustLibraryDirectory)"], .when(platforms: [.macOS])),
                .linkedLibrary("sweepdeck_accelerator", .when(platforms: [.macOS]))
            ]
        ),
        .target(name: "SweepdeckAppearance", dependencies: ["SweepdeckCore"]),
        .target(name: "SweepdeckPresentation"),
        .executableTarget(name: "Sweepdeck", dependencies: ["SweepdeckCore", "SweepdeckAppearance", "SweepdeckPresentation"]),
        .testTarget(name: "SweepdeckCoreTests", dependencies: ["SweepdeckCore"]),
        .testTarget(name: "SweepdeckAppearanceTests", dependencies: ["SweepdeckAppearance", "SweepdeckCore"]),
        .testTarget(name: "SweepdeckPresentationTests", dependencies: ["SweepdeckPresentation"])
    ]
)
