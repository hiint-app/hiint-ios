// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Hiint",
    platforms: [.iOS(.v15), .macOS(.v12)],
    products: [
        .library(name: "Hiint", targets: ["Hiint"])
    ],
    targets: [
        .target(name: "Hiint"),
        .testTarget(name: "HiintTests", dependencies: ["Hiint"]),
    ]
)
