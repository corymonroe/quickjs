const std = @import("std");

fn add_defines(c: *std.Build.Step.Compile) void {
    c.root_module.addCMacro("CONFIG_VERSION", "\"2025-04-26\"");
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const quickjs_source = &.{
        "quickjs.c",
        "dtoa.c",
        "libregexp.c",
        "libunicode.c",
        "cutils.c",
        "quickjs-libc.c",
    };

    const cflags = &.{
        "-Wall",
        "-Wextra",
        "-Wchar-subscripts",
        "-Wundef",
        "-Wuninitialized",
        "-Wunused",
        "-Wwrite-strings",
        "-Wno-cast-function-type",
        "-Wno-ignored-attributes",
        "-Wno-sign-compare",
        "-Wno-unused-parameter",
        "-Wno-unused-variable",
        "-Wno-unused-but-set-variable",
        "-funsigned-char",
        "-fwrapv",
        "-Werror",
    };

    const quickjs_lib = b.addLibrary(.{
        .name = "quickjs",
        .linkage = .static,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    quickjs_lib.want_lto = optimize != .Debug;

    quickjs_lib.addCSourceFiles(.{
        .files = quickjs_source,
        .flags = cflags,
    });

    quickjs_lib.installHeader(b.path("quickjs.h"), "quickjs.h");

    add_defines(quickjs_lib);

    b.installArtifact(quickjs_lib);

    const qjsc = b.addExecutable(.{
        .name = "qjsc",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });

    qjsc.addCSourceFile(.{
        .file = b.path("qjsc.c"),
        .flags = cflags,
    });

    qjsc.linkLibrary(quickjs_lib);

    add_defines(qjsc);

    b.installArtifact(qjsc);

    const qjsc_host = b.addExecutable(.{
        .name = "qjsc-host",
        .root_module = b.createModule(.{
            .target = b.graph.host,
            .optimize = optimize,
            .link_libc = true,
        }),
        .linkage = .static,
    });

    qjsc_host.addCSourceFile(.{
        .file = b.path("qjsc.c"),
        .flags = cflags,
    });

    qjsc_host.addCSourceFiles(.{
        .files = quickjs_source,
        .flags = cflags,
    });

    add_defines(qjsc_host);

    const gen_repl = b.addRunArtifact(qjsc_host);
    gen_repl.addArg("-s");
    gen_repl.addArg("-c");
    gen_repl.addArg("-N");
    gen_repl.addArg("qjsc_repl");
    gen_repl.addArg("-o");
    const gen_repl_out = gen_repl.addOutputFileArg("repl.c");
    gen_repl.addArg("-m");
    gen_repl.addFileArg(b.path("repl.js"));

    const qjs = b.addExecutable(.{
        .name = "qjs",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
        .linkage = .static,
    });
    qjs.want_lto = optimize != .Debug;

    qjs.addCSourceFile(.{
        .file = b.path("qjs.c"),
        .flags = cflags,
    });

    qjs.addCSourceFile(.{
        .file = gen_repl_out,
        .flags = cflags,
    });

    qjs.linkLibrary(quickjs_lib);

    add_defines(qjs);

    qjs.step.dependOn(&gen_repl.step);

    b.installArtifact(qjs);
}
