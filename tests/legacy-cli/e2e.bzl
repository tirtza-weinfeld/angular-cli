load("@build_bazel_rules_nodejs//:index.bzl", "nodejs_test")

# bazel query --output=label "kind('pkg_tar', //packages/...)"
TESTED_PACKAGES = [
    "//packages/angular/cli:npm_package_archive.tgz",
    "//packages/angular/create:npm_package_archive.tgz",
    "//packages/angular/pwa:npm_package_archive.tgz",
    "//packages/angular_devkit/architect:npm_package_archive.tgz",
    "//packages/angular_devkit/architect_cli:npm_package_archive.tgz",
    # this is private so don't use here
    # "//packages/angular_devkit/benchmark:npm_package_archive.tgz",
    "//packages/angular_devkit/build_angular:npm_package_archive.tgz",
    "//packages/angular_devkit/build_webpack:npm_package_archive.tgz",
    "//packages/angular_devkit/core:npm_package_archive.tgz",
    "//packages/angular_devkit/schematics:npm_package_archive.tgz",
    "//packages/angular_devkit/schematics_cli:npm_package_archive.tgz",
    "//packages/ngtools/webpack:npm_package_archive.tgz",
    "//packages/schematics/angular:npm_package_archive.tgz",
]

# Number of bazel shards per test target
TEST_SHARD_COUNT = 4

# NB: does not run on rbe because webdriver manager uses an absolute path to chromedriver
# Requires network to fetch npm packages.
TEST_TAGS = ["no-remote-exec", "requires-network"]

# Subset of tests for yarn/esbuild
BROWSER_TESTS = ["tests/misc/browsers.js"]
YARN_TESTS = ["tests/basic/**", "tests/update/**", "tests/commands/add/**"]
ESBUILD_TESTS = ["tests/basic/**", "tests/build/prod-build.js"]

# Tests excluded for esbuild
ESBUILD_IGNORE_TESTS = [
    "tests/basic/environment.js",
    "tests/basic/rebuild.js",
    "tests/basic/serve.js",
    "tests/basic/scripts-array.js",
]

def _to_glob(patterns):
    if len(patterns) == 1:
        return patterns[0]

    return "\"{%s}\"" % ",".join(patterns)

def e2e_suites(name, runner, data):
    """
    Construct all e2e test suite targets

    Args:
        name: the prefix to all rules
        runner: the e2e test runner entry point
        data: runtime deps such as tests and test data
    """

    # Default target meant to be run manually for debugging, customizing test cli via bazel
    _e2e_tests(name, runner = runner, data = data, tags = ["manual"])

    # Pre-configured test suites
    # TODO: add node 14 + 16
    _e2e_suite(name, runner, "npm", data)
    _e2e_suite(name, runner, "yarn", data)
    _e2e_suite(name, runner, "esbuild", data)
    _e2e_suite(name, runner, "saucelabs", data)

def _e2e_tests(name, runner, **kwargs):
    # Always specify all the npm packages
    args = kwargs.pop("templated_args", []) + ["--package"] + [
        "$(rootpath %s)" % p
        for p in TESTED_PACKAGES
    ]

    # Always add all the npm packages as data
    data = kwargs.pop("data", []) + TESTED_PACKAGES

    # Tags that must always be applied
    tags = kwargs.pop("tags", []) + TEST_TAGS

    # Passthru E2E variables in case it is customized by CI etc
    configuration_env_vars = kwargs.pop("configuration_env_vars", []) + ["E2E_TEMP", "E2E_SHARD_INDEX", "E2E_SHARD_TOTAL"]

    env = kwargs.pop("env", {})
    toolchains = kwargs.pop("toolchains", [])

    # The git toolchain + env
    env.update({"GIT_BIN": "$(GIT_BIN_PATH)"})
    toolchains = toolchains + ["@npm//@angular/build-tooling/bazel/git-toolchain:current_git_toolchain"]

    # Chromium browser toolchain
    env.update({
        "CHROME_BIN": "$(CHROMIUM)",
        "CHROMEDRIVER_BIN": "$(CHROMEDRIVER)",
    })
    toolchains = toolchains + ["@npm//@angular/build-tooling/bazel/browsers/chromium:toolchain_alias"]
    data = data + ["@npm//@angular/build-tooling/bazel/browsers/chromium"]

    nodejs_test(
        name = name,
        templated_args = args,
        data = data,
        entry_point = runner,
        env = env,
        configuration_env_vars = configuration_env_vars,
        tags = tags,
        toolchains = toolchains,
        **kwargs
    )

def _e2e_suite(name, runner, type, data):
    """
    Setup a predefined test suite (yarn|esbuild|saucelabs|npm).
    """
    args = []
    tests = None
    ignore = None

    if type == "yarn":
        args.append("--yarn")
        tests = YARN_TESTS
        ignore = BROWSER_TESTS
    elif type == "esbuild":
        args.append("--esbuild")
        tests = ESBUILD_TESTS
        ignore = BROWSER_TESTS + ESBUILD_IGNORE_TESTS
    elif type == "saucelabs":
        tests = BROWSER_TESTS
        ignore = None
    elif type == "npm":
        tests = None
        ignore = BROWSER_TESTS

    # Standard e2e tests
    _e2e_tests(
        name = "%s.%s" % (name, type),
        runner = runner,
        size = "enormous",
        data = data,
        shard_count = TEST_SHARD_COUNT,
        templated_args = [
            "--glob=%s" % _to_glob(tests) if tests else "",
            "--ignore=%s" % _to_glob(ignore) if ignore else "",
        ],
    )

    # e2e tests of snapshot builds
    _e2e_tests(
        name = "%s.snapshot.%s" % (name, type),
        runner = runner,
        size = "enormous",
        data = data,
        shard_count = TEST_SHARD_COUNT,
        templated_args = [
            "--ng-snapshots",
            "--glob=%s" % _to_glob(tests) if tests else "",
            "--ignore=%s" % _to_glob(ignore) if ignore else "",
        ],
    )