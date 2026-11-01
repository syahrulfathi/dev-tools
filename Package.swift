// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "dev-tools",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "dev-tools", targets: ["DevTools"])],
    targets: [
        .target(name: "DevToolsCore", resources: [.copy("Resources/yaml.rb")]),
        .executableTarget(name: "DevTools", dependencies: ["DevToolsCore"]),
        .executableTarget(name: "DevToolsChecks", dependencies: ["DevToolsCore"], path: "Tests/DevToolsCoreTests")
    ]
)
