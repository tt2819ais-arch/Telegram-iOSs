load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

# Local store for deleted and edited messages.
# Stage 1 ships only the API surface; Stage 5 wires the interception points
# into the upstream message handling pipeline.
swift_library(
    name = "NexusMessageHistory",
    module_name = "NexusMessageHistory",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Nexus/NexusCore:NexusCore",
    ],
    visibility = [
        "//visibility:public",
    ],
)
