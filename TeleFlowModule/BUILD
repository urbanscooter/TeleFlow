load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "TeleFlow",
    module_name = "TeleFlow",
    srcs = glob(["Sources/*.swift"]),
    visibility = ["//visibility:public"],
)

objc_library(
    name = "TeleFlowBootstrap",
    srcs = glob(["Sources/*.m"]),
    enable_modules = True,
    visibility = ["//visibility:public"],
    sdk_frameworks = [
        "UIKit",
        "Foundation",
    ],
    deps = [":TeleFlow"],
)
