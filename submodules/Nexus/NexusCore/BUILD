load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

# Shared types and constants for Nexus features.
# Other Nexus modules depend on this; it has no external dependencies of its own.
swift_library(
    name = "NexusCore",
    module_name = "NexusCore",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
    ],
    visibility = [
        "//visibility:public",
    ],
)
