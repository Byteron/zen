const std = @import("std");
const raylib = @import("libs/raylib/src/build.zig");

pub fn build(b: *std.build.Builder) void {
    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();
    const target = b.standardTargetOptions(.{});

    const rl = raylib.addRaylib(b, target);
    const lib = b.addStaticLibrary("zen", "src/main.zig");
    lib.addPackagePath("zapp", "libs/zapp/src/main.zig");
    lib.addPackagePath("zecs", "libs/zecs/src/main.zig");
    lib.linkLibrary(rl);
    lib.setBuildMode(mode);
    lib.install();

    const main_tests = b.addTest("src/main.zig");
    main_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);
}
