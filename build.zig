const std = @import("std");

pub fn build(b: *std.Build) void {
    const exe = b.addExecutable(.{
        .name = "echo-server",
        .root_source_file = b.path("poll.zig"),
        .target = b.host,
    });

    b.installArtifact(exe);
}
