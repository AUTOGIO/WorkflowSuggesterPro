// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "WorkflowSuggesterPro",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(
            name: "WorkflowSuggesterPro",
            targets: ["WorkflowSuggesterPro"]
        ),
        .executable(
            name: "WorkflowSuggesterProApp",
            targets: ["WorkflowSuggesterProApp"]
        ),
    ],
    targets: [
        .target(
            name: "WorkflowSuggesterCore",
            path: "Sources/WorkflowSuggesterCore"
        ),
        .executableTarget(
            name: "WorkflowSuggesterPro",
            dependencies: ["WorkflowSuggesterCore"],
            path: "Sources/WorkflowSuggesterPro"
        ),
        .executableTarget(
            name: "WorkflowSuggesterProApp",
            dependencies: ["WorkflowSuggesterCore"],
            path: "Sources/WorkflowSuggesterProApp"
        ),
        .testTarget(
            name: "WorkflowSuggesterProTests",
            dependencies: ["WorkflowSuggesterCore"],
            path: "Tests/WorkflowSuggesterProTests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
