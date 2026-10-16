// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ChiikawaCompanion",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "ChiikawaCompanion", targets: ["ChiikawaCompanion"])],
    targets: [.executableTarget(name: "ChiikawaCompanion", resources: [.copy("Resources")])]
)
