const std = @import("std");
const zigflag = @import("src/root.zig");
const defaults = @import("./flags_init.zig").defaults;

pub fn main(init: std.process.Init) !void {

    const io = init.io;
    const min = init.minimal;

    var stderr_writer: std.Io.File.Writer = .init( .stderr(), io, &.{});
    const stderr = &stderr_writer.interface;
    defer stderr.flush() catch {};

    var stdout_writer: std.Io.File.Writer = .init( .stdout(), io, &.{});
    const stdout = &stdout_writer.interface;
    defer stdout.flush() catch {};

    const parsecfg: zigflag.Type.ParseConfig = .{
        .allowDashInput = true,
        .allowDups = true,
        .verbose = true,
        .writer = stderr,
        .prefix = "my-program: "
    };
    
    // points to erred flag
    var errptr: ?[]const u8 = null;
    // actual parse, returns a tuple of Flags and resulting args
    const result = try zigflag.parse(init.gpa, min.args, defaults, &errptr, parsecfg);
    defer result.deinit(init.gpa);

    const flags = result.flags;
    std.debug.print("recursive: {}\n", .{flags.recursive});
    std.debug.print("force: {}\n", .{flags.force});

    if (flags.files) |files| {
        for (files) |file| {
            std.debug.print("{s}\n", .{file});
        }
    }
}
