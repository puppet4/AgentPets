// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AgentPets",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "AgentPets", targets: ["AgentPets"])
    ],
    targets: [
        .executableTarget(
            name: "AgentPets",
            path: "Sources/AgentPets",
            exclude: [
                "App/Info.plist",
                "App/AgentPets.icns"
            ],
            resources: [
                .copy("Resources")
            ],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        ),
        .testTarget(
            name: "AgentPetsTests",
            dependencies: ["AgentPets"]
        )
    ]
)
