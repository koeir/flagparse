const std = @import("std");
const zigflag = @import("src/root.zig");
const defaults = @import("./flags_init.zig").defaults;

pub fn main(init: std.process.Init) !void {

    const io = init.io;
    const min = init.minimal;

    var stderr_writer: std.Io.File.Writer = .init( .stderr(), io, &.{});
    const stderr = &stderr_writer.interface;
    defer stderr.flush() catch {};

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
    defer result.deinit();

    const flags = result.flags;
    std.debug.print("recursive: {}\n", .{flags.recursive});
    std.debug.print("force: {}\n", .{flags.force});

    std.debug.print("\n", .{});
    if (flags.files) |files| {
        std.debug.print("files:\n", .{});
        for (files) |file| {
            std.debug.print("{s} ", .{file});
        } std.debug.print("\n", .{});
    }

    std.debug.print("\n", .{});
    if (result.argv) |args| {
        std.debug.print("flagless args:\n", .{});
        for (args) |arg| {
            std.debug.print("{s} ", .{arg});
        } std.debug.print("\n", .{});
    }
}
