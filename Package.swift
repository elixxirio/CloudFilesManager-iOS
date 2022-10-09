// swift-tools-version: 5.7

import PackageDescription

let package = Package(
  name: "xxm-cloud-providers",
  defaultLocalization: "en",
  platforms: [.iOS(.v14),],
  products: [
    .library(name: "CloudFiles", targets: ["CloudFiles"]),
    .library(name: "CloudFilesSFTP", targets: ["CloudFilesSFTP"]),
    .library(name: "CloudFilesDrive", targets: ["CloudFilesDrive"]),
    .library(name: "CloudFilesICloud", targets: ["CloudFilesICloud"]),
    .library(name: "CloudFilesDropbox", targets: ["CloudFilesDropbox"])
  ],
  dependencies: [
    .package(
      url: "https://github.com/google/GoogleSignIn-iOS",
      .upToNextMajor(from: "6.1.0")
    ),
    .package(
      url: "https://github.com/dropbox/SwiftyDropbox.git",
      .upToNextMajor(from: "9.0.0")
    ),
    .package(
      url: "https://github.com/amosavian/FileProvider.git",
      .upToNextMajor(from: "0.26.0")
    ),
    .package(
      url: "https://github.com/darrarski/Shout.git",
      revision: "df5a662293f0ac15eeb4f2fd3ffd0c07b73d0de0"
    ),
    .package(
      url: "https://github.com/google/google-api-objectivec-client-for-rest",
      .upToNextMajor(from: "2.0.1")
    ),
  ],
  targets: [
    .target(
      name: "CloudFiles"
    ),
    .target(
      name: "CloudFilesSFTP",
      dependencies: [
        .target(
          name: "CloudFiles"
        ),
        .product(
          name: "Shout",
          package: "Shout"
        )
      ]
    ),
    .testTarget(
      name: "CloudFilesSFTPTests",
      dependencies: [
        .target(name: "CloudFilesSFTP")
      ]
    ),
    .target(
      name: "CloudFilesICloud",
      dependencies: [
        .target(
          name: "CloudFiles"
        ),
        .product(
          name: "FilesProvider",
          package: "FileProvider"
        )
      ]
    ),
    .testTarget(
      name: "CloudFilesICloudTests",
      dependencies: [
        .target(name: "CloudFilesICloud")
      ]
    ),
    .target(
      name: "CloudFilesDropbox",
      dependencies: [
        .target(
          name: "CloudFiles"
        ),
        .product(
          name: "SwiftyDropbox",
          package: "SwiftyDropbox"
        )
      ]
    ),
    .testTarget(
      name: "CloudFilesDropboxTests",
      dependencies: [
        .target(name: "CloudFilesDropbox")
      ]
    ),
    .target(
      name: "CloudFilesDrive",
      dependencies: [
        .target(
          name: "CloudFiles"
        ),
        .product(
          name: "GoogleSignIn",
          package: "GoogleSignIn-iOS"
        ),
        .product(
          name: "GoogleAPIClientForREST_Drive",
          package: "google-api-objectivec-client-for-rest"
        )
      ]
    ),
    .testTarget(
      name: "CloudFilesDriveTests",
      dependencies: [
        .target(name: "CloudFilesDrive")
      ]
    )
  ]
)
