// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MDown",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "MDown", path: "Sources/MDown")
    ],
    swiftLanguageVersions: [.v5]
)
