// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CircuitToyCore",
    platforms: [.iOS("27.0"), .macOS(.v15)],
    products: [.library(name: "CircuitCore", targets: ["CircuitCore"])],
    targets: [
        .target(name: "CircuitCore"),
        .target(name: "CircuitScience", path: "App", sources: ["ScientificModels.swift"]),
        .target(name: "CircuitAdvanced", path: "App", sources: ["FoundationsModels.swift", "SystemsModels.swift", "EngineeringModels.swift", "PracticeModels.swift"]),
        .target(name: "CircuitCurriculum", path: "App", sources: ["CurriculumData.swift", "LessonCatalog.swift"]),
        .target(name: "CircuitBreadboardStore", dependencies: ["CircuitCore"], path: "App", sources: ["BreadboardStore.swift"]),
        .testTarget(name: "CircuitCoreTests", dependencies: ["CircuitCore"]),
        .testTarget(name: "ScientificModelsTests", dependencies: ["CircuitScience"], path: "Tests/ScientificModelsTests"),
        .testTarget(name: "AdvancedModelsTests", dependencies: ["CircuitAdvanced", "CircuitCurriculum"], path: "Tests/AdvancedModelsTests"),
        .testTarget(name: "BreadboardStoreTests", dependencies: ["CircuitBreadboardStore", "CircuitCore"], path: "Tests/BreadboardStoreTests")
    ]
)
