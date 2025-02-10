const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Build your own library and executable first:
    const lib = b.addStaticLibrary(.{
        .name = "chip8",
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(lib);

    const exe = b.addExecutable(.{
        .name = "chip8",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    
    exe.linkLibC();

    // Now declare the SDL dependency. The first parameter "sdl" is the name
    // under which zig fetch saved the dependency.
    const sdl_dep = b.dependency("sdl", .{
        .target = target,
        .optimize = optimize,
        // You can optionally set .preferred_link_mode if needed:
        // .preferred_link_mode = .static, // or .dynamic
    });
    const sdl_lib = sdl_dep.artifact("SDL3");
    exe.root_module.linkLibrary(sdl_lib);
    // // Retrieve the output artifact for the SDL library.
    // // According to the repository usage, the SDL library is built and exposes an artifact
    // // under the name "SDL3". (There is also one for tests, "SDL3_test".)
    // const sdl_lib = sdl_dep.artifact("SDL3");
    // exe.addIncludePath(b.path("SDL/include"));
    // // Link the SDL library to your executable.
    // exe.linkLibrary(sdl_lib);

    // Install your executable.
    b.installArtifact(exe);

    // (Optional) Set up run and test steps…
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
