// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "sms_autofill",
    platforms: [
        .iOS("12.0"),
    ],
    products: [
        .library(name: "sms-autofill", targets: ["sms_autofill"]),
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
    ],
    targets: [
        .target(
            name: "sms_autofill",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
            ],
            cSettings: [
                .headerSearchPath("include/sms_autofill"),
            ]
        ),
    ]
)
