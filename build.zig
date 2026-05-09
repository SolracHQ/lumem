const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("lumem", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });
    mod.link_libc = true;

    const zua = b.dependency("zua", .{ .target = target, .optimize = optimize });
    mod.addImport("zua", zua.module("zua"));

    const exe = b.addExecutable(.{
        .name = "lumem",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "lumem", .module = mod },
            },
        }),
    });
    exe.root_module.link_libc = true;

    exe.root_module.addImport("zua", zua.module("zua"));

    exe.root_module.addIncludePath(b.path("vendor/linenoise"));

    b.installArtifact(exe);

    const docs_exe = b.addExecutable(.{
        .name = "lumem-docs",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/docs.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "lumem", .module = mod },
            },
        }),
    });
    docs_exe.root_module.link_libc = true;
    docs_exe.root_module.addImport("zua", zua.module("zua"));

    const docs_cmd = b.addRunArtifact(docs_exe);
    const docs_step = b.step("docs", "Generate Lua type stubs");
    docs_step.dependOn(&docs_cmd.step);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });
    const run_mod_tests = b.addRunArtifact(mod_tests);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });
    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
}
