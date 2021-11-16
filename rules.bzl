"""
Rules to use the prebuilt buildifier / buildozer binaries
"""

load("@bazel_skylib//lib:shell.bzl", "shell")

def _buildifier_binary(ctx):
    buildifier = ctx.toolchains["@buildifier_prebuilt//:toolchain"]._buildifier
    script = ctx.actions.declare_file("buildifier.sh")
    ctx.actions.write(
        script,
        """\
#!/usr/bin/env bash

exec {buildifier} "$@"
""".format(buildifier = buildifier.short_path),
        is_executable = True,
    )

    return [
        DefaultInfo(
            runfiles = ctx.runfiles(files = [buildifier]),
            executable = script,
        ),
    ]

buildifier_binary = rule(
    implementation = _buildifier_binary,
    attrs = {},
    toolchains = ["@buildifier_prebuilt//:toolchain"],
    executable = True,
)

def _buildozer_binary(ctx):
    buildozer = ctx.toolchains["@buildifier_prebuilt//:toolchain"]._buildozer
    script = ctx.actions.declare_file("buildozer.sh")
    ctx.actions.write(
        script,
        """\
#!/usr/bin/env bash

exec {buildozer} "$@"
""".format(buildozer = buildozer.short_path),
        is_executable = True,
    )

    return [
        DefaultInfo(
            runfiles = ctx.runfiles(files = [buildozer]),
            executable = script,
        ),
    ]

buildozer_binary = rule(
    implementation = _buildozer_binary,
    attrs = {},
    toolchains = ["@buildifier_prebuilt//:toolchain"],
    executable = True,
)

def _buildifier(ctx):
    args = [
        "-mode=%s" % ctx.attr.mode,
        "-v=%s" % str(ctx.attr.verbose).lower(),
    ]

    if ctx.attr.lint_mode:
        args.append("-lint=%s" % ctx.attr.lint_mode)

    if ctx.attr.lint_warnings:
        if not ctx.attr.lint_mode:
            fail("Cannot pass 'lint_warnings' without a 'lint_mode'")
        args.append("--warnings={}".format(",".join(ctx.attr.lint_warnings)))

    if ctx.attr.add_tables:
        args.append("-add_tables=%s" % ctx.file.add_tables.path)

    exclude_patterns_str = ""
    if ctx.attr.exclude_patterns:
        exclude_patterns = ["\\! -path %s" % shell.quote(pattern) for pattern in ctx.attr.exclude_patterns]
        exclude_patterns_str = " ".join(exclude_patterns)

    buildifier = ctx.toolchains["@buildifier_prebuilt//:toolchain"]._buildifier
    out_file = ctx.actions.declare_file(ctx.label.name + ".bash")
    substitutions = {
        "@@ARGS@@": shell.array_literal(args),
        "@@BUILDIFIER_SHORT_PATH@@": shell.quote(buildifier.short_path),
        "@@EXCLUDE_PATTERNS@@": exclude_patterns_str,
    }
    ctx.actions.expand_template(
        template = ctx.file._runner,
        output = out_file,
        substitutions = substitutions,
        is_executable = True,
    )

    return DefaultInfo(
        files = depset([out_file]),
        runfiles = ctx.runfiles(files = [buildifier]),
        executable = out_file,
    )

buildifier = rule(
    implementation = _buildifier,
    attrs = {
        "verbose": attr.bool(
            doc = "Print verbose information on standard error",
        ),
        "mode": attr.string(
            default = "fix",
            doc = "Formatting mode",
            values = ["check", "diff", "print_if_changed", "fix"],
        ),
        "lint_mode": attr.string(
            doc = "Linting mode",
            values = ["", "warn", "fix"],
        ),
        "lint_warnings": attr.string_list(
            allow_empty = True,
            doc = "all prefixed with +/- if you want to include in or exclude from the default set of warnings, or none prefixed with +/- if you want to override the default set, or 'all' for all available warnings",
        ),
        "add_tables": attr.label(
            mandatory = False,
            doc = "path to JSON file with custom table definitions which will be merged with the built-in tables",
            allow_single_file = True,
        ),
        "exclude_patterns": attr.string_list(
            allow_empty = True,
            doc = "A list of glob patterns passed to the find command. E.g. './vendor/*' to exclude the Go vendor directory",
        ),
        "_runner": attr.label(
            default = "@buildifier_prebuilt//:runner.bash.template",
            allow_single_file = True,
        ),
    },
    toolchains = ["@buildifier_prebuilt//:toolchain"],
    executable = True,
)
