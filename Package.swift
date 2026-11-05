// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "TruncationTokenCrash",
    platforms: [.iOS(.v12)],
    products: [],
    targets: [
        .target(
            name: "TTTAttributedLabel",
            path: "TTTAttributedLabel",
            sources: ["TTTAttributedLabel.m"],
            publicHeadersPath: ".",
            linkerSettings: [
                .linkedFramework("UIKit"),
                .linkedFramework("CoreText"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("QuartzCore"),
            ]
        ),
        .testTarget(
            name: "TruncationTokenCrashTests",
            dependencies: ["TTTAttributedLabel"],
            path: "Example/TTTAttributedLabelTests",
            sources: ["LinkedTruncationTokenCrashTests.m", "LinkedTruncationTokenVariantTests.m"],
            linkerSettings: [
                .linkedFramework("UIKit"),
                .linkedFramework("CoreText"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("QuartzCore"),
            ]
        ),
    ]
)
