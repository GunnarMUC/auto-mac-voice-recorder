// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CallRecorder",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "Dependencies/whisper.spm"),
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.15.0"),
    ],
    targets: [
        .executableTarget(
            name: "CallRecorder",
            dependencies: [
                .product(name: "whisper", package: "whisper.spm"),
                .product(name: "SQLite", package: "SQLite.swift"),
            ]
        ),
        .executableTarget(
            name: "PoC",
            dependencies: [
                .product(name: "whisper", package: "whisper.spm"),
            ]
        ),
    ]
)
