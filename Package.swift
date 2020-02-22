// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "git-ps",
    platforms: [
        SupportedPlatform.macOS(SupportedPlatform.MacOSVersion.v10_13)
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/uptech/JsonFileManager.git", Package.Dependency.Requirement.upToNextMajor(from: Version(2, 0, 0)))
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "git-ps",
            dependencies: ["GitPatchStackCore"]),
        .target(
            name: "GitPatchStackCore",
            dependencies: ["JsonFileManager"]),
        .testTarget(
            name: "git-psTests",
            dependencies: ["git-ps"]),
    ]
)
