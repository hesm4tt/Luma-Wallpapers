// swift-tools-version:5.9
import PackageDescription
let package = Package(name: "Check", platforms: [.macOS(.v13)], dependencies: [.package(path: "../../Vendor/ZIPFoundation")], targets: [.executableTarget(name: "Check", dependencies: [.product(name: "ZIPFoundation", package: "ZIPFoundation")])])
