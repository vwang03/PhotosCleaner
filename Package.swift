// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PhotoCleaner",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "PhotoCleanerCore", targets: ["PhotoCleanerCore"]),
        .executable(name: "PhotoCleaner", targets: ["PhotoCleaner"])
    ],
    targets: [
        .target(
            name: "PhotoCleanerCore",
            dependencies: [],
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        .executableTarget(
            name: "PhotoCleaner",
            dependencies: ["PhotoCleanerCore"]
        ),
        .testTarget(
            name: "PhotoCleanerCoreTests",
            dependencies: ["PhotoCleanerCore"]
        )
    ]
)
