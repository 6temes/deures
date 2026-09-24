// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "Gate",
  platforms: [
    .iOS(.v26),
    .macOS(.v15)
  ],
  products: [
    .library(name: "GateCore", targets: ["GateCore"]),
    .library(name: "GateKit", targets: ["GateKit"])
  ],
  targets: [
    .target(name: "GateCore"),
    .target(name: "GateKit", dependencies: ["GateCore"]),
    .testTarget(name: "GateCoreTests", dependencies: ["GateCore"]),
    .testTarget(name: "GateKitTests", dependencies: ["GateKit"])
  ]
)
