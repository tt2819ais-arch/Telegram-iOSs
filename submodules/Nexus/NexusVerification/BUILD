load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

# Client-side fake verification badge and admin panel.
# Stage 1 ships only the persistence layer and the admin authentication
# gate; UI rendering and admin panel UX land in Stages 4 and 5.
swift_library(
    name = "NexusVerification",
    module_name = "NexusVerification",
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
