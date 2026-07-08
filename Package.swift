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
        )
    ],
    targets: [
        .executableTarget(
            name: "WorkflowSuggesterPro",
            path: "Sources/WorkflowSuggesterPro"
        ),
        .testTarget(
            name: "WorkflowSuggesterProTests",
            dependencies: ["WorkflowSuggesterPro"],
            path: "Tests/WorkflowSuggesterProTests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
