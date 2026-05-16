// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StudyPulsNative",
    platforms: [
        .macOS(.v14),
        .iOS(.v16)
    ],
    products: [
        .executable(name: "StudyPulsDashboard", targets: ["StudyPulsDashboard"])
    ],
    targets: [
        .executableTarget(
            name: "StudyPulsDashboard",
            path: "Apps/StudyPulsDashboard/Sources"
        )
    ]
)
