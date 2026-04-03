const std = @import("std");
const flag = @import("flagparse");

pub fn main() !void {
    var stdout_buf: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buf);
    const stdout = &stdout_writer.interface;
    defer stdout.flush() catch {};

    // parse requires       vvvvvvvvvvvv
    var args: std.process.ArgIteratorPosix = .init();

    const Result = flag.init(Flags);
    var flags: Result = try flag.parse(&args, Flags, Result);

    _ = &flags; // debug
    if (flags.@"recursive".@"long") |long| {
        std.debug.print("Longhand:  --{s}\n", .{ long });
    }
    if (flags.@"recursive".@"short") |short| {
        std.debug.print("Shorthand: -{c}\n", .{ short });
    }

    const recursive: flag.FlagVal = flags.@"recursive".@"value";
    switch ( recursive ) {
        .Switch => |val| std.debug.print("Recursion is {}\n", .{ val }),
        .Argumentative => unreachable,
    }
}

const Flags = struct {
    pub const recursive: flag.Flag = .{
        .long = "recursive",
        .short = 'r', 
        .value = .{ .Switch = false },
        .opt = true,
        .desc = null,
    };

    pub const force: flag.Flag = .{
        .long = "force",
        .short = 'f',
        .value = .{ .Switch = false },
        .opt = true,
        .desc = "Skip confirmation prompts",
    };
};
