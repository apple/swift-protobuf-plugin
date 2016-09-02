import PackageDescription

// WARNING:  The Version of the plugin (in Sources/Version.swift) MUST match
// the runtime library version here.  (The Documentation tells people to
// use the matching runtime library.)

let package = Package(
        name: "protoc-gen-swift",
        dependencies: [
          .Package(
              url: "https://gitlab.sd.apple.com/tkientzle/SwiftProtobufRuntime.git",
              Version(0,9,13)
          ),
        ]
)
