// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OpenAI",
    platforms: [.iOS(.v13), .macCatalyst(.v13), .macOS(.v12)],
    products: [
        .library(name: "OpenAI", targets: ["OpenAI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", .upToNextMajor(from: "5.6.4")),
        .package(url: "https://github.com/AxApp/OpenAICore", .upToNextMajor(from: "0.0.2"))
    ],
    targets: [
        .target(name: "OpenAI",
                dependencies: [
                    "Alamofire",
                    "OpenAICore"
                ]),
        .testTarget(
            name: "OpenAITests",
            dependencies: ["OpenAI", "Alamofire"]),
    ]
)
