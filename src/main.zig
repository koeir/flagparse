const std = @import("std");
const flag = @import("flagparse");

pub fn main() !void {
    var stdout_buf: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buf);
    const stdout = &stdout_writer.interface;
    defer stdout.flush() catch {};

    // parse requires       vvvvvvvvvvvv
    var args: std.process.ArgIteratorPosix = .init();

    // .init makes a mutable runtime version of the initialized Flags
    // Declarations are turned into fields
    //
    //          v COMPTIME STRUCT v                       v RUNTIME STRUCT v
    // _____________________________________       _________________________________
    // [ const Flags = struct {            ]       [   const Result = struct {     ]
    // [      pub const recursive = ...    ]  -->  [       .recursive = ...        ]
    // [___________________________________]       [_______________________________]
    const Result = comptime flag.init(Flags);

    // Make a mutable instance populated with the default values
    var mut_flags = Result{};

    // (WIP)
    // parse is a runtime function that actually changes
    // the values of the mutable
    var flags: Result = try flag.parse(&args, Flags, Result);
    _ = &flags;

    // Mutate value
    try stdout.print("Force: {}\n", .{ mut_flags.force.value });
    mut_flags.force.value = .{ .Switch = true };
    try stdout.print("Force: {}\n", .{ mut_flags.force.value });

    try stdout.print("\n", .{});

    // Long hands and short hands
    if (flags.recursive.long) |long| {
        try stdout.print("Longhand:  --{s}\n", .{ long });
    }
    if (flags.recursive.short) |short| {
        try stdout.print("Shorthand: -{c}\n", .{ short });
    }

    try stdout.print("Recursion is: {}\n", .{ flags.recursive.value.Switch });
}

// Initialize flags and their default values
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
