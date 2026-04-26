load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

# MTProto proxy auto-discovery and selection for Nexus.
# Stage 1 ships only the public API surface; the implementation lands in Stage 2.
swift_library(
    name = "NexusAutoProxy",
    module_name = "NexusAutoProxy",
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
