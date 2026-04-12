const std = @import("std");
const flag = @import("flagparse");

pub fn main() !void {
    var stderr_buf: [1024]u8 = undefined;
    var stderr_writer = std.fs.File.stderr().writer(&stderr_buf);
    const stderr = &stderr_writer.interface;
    defer stderr.flush() catch {};

    var stdout_buf: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buf);
    const stdout = &stdout_writer.interface;
    defer stdout.flush() catch {};

    var args: std.process.ArgIteratorPosix = .init();

    // Make mutable flag array "buffer" in stack
    var flagarr: [initflags.list.len]flag.Flag = undefined;
    const flags = flag.parse(&args, initflags, &flagarr, 
    .{ .AllowDups = false, .verbose = true, .writer = stderr }) catch |err| {
        const arg: []const u8 = std.mem.sliceTo(std.os.argv[args.index - 1], 0);
        const fmt = flag.flagfmt(arg) orelse return err;
        var flagtmp: *const flag.Flag = undefined;

        try stdout.writeAll("Usage:\n");
        switch (fmt) {
            .Long   => |_| {
                flagtmp = flag.get_long_flag(&flagarr, arg[2..], .{}) catch { return err; };
                try stdout.print("{f}\n", .{ flagtmp.* });
            },
            .Short  => |_| {
                for (arg) |c| {
                    flagtmp = flag.get_short_flag(&flagarr, c, .{}) catch { continue; };
                    try stdout.print("{f}\n", .{ flagtmp.* });
                }
            }
        }

        try stdout.writeAll("\n");
        return err;
    };

    try stdout.writeAll("Toggled flags:\n");
    // Formatted print for each flag
    for (flags.list) |f| {
        if (!try f.isDefault(initflags)) try stdout.print("{f}\n", .{ f } );
    }

    try stdout.writeAll("\n");
    try stdout.writeAll("Values:\n");
    for (flags.list) |f| {
        if (try f.isDefault(initflags)) continue;

        try stdout.print("{s}: {f}\n", .{ f.name, f.value });
    }

    try stdout.writeAll("\n");
    try stdout.print("The path is {s}!\n", .{ try flags.get_value("file", [1024:0]u8) });
    try stdout.print("Recursion is {any}\n", .{ try flags.get_value("recursive", bool) });

    // Also works with the Flags struct
    try stdout.writeAll("\n");
    try stdout.writeAll("Options:\n");
    try stdout.print("{f}", .{ initflags });
}

// Initialize flags and their default values
// name doesn't really matter as long as the 
// members are all of type Flag
const initflags: flag.Flags = .{
    .list = &[_] flag.Flag 
    {
            flag.Flag {
                .name = "recursive",
                .long = "recursive",
                .short = 'r',
                .value = .{ .Switch = false },
                .desc = "Recurse into directories",
            },

            flag.Flag {
                .name = "force",
                .long = "force",
                .short = 'f',
                .value = .{ .Switch = false },
                .desc = "Skip confirmation prompts",
            },

        // Arguments will accept the next argv
        // e.g. -prf noob
        // "noob" will be accepted as the file
        //
        // They will however, NOT accept any arg that starts with "-"
        // e.g. -p -r noob
        // will yield an error
            flag.Flag {
                .name = "file",
                .long = "path",
                .short = 'p',
                // Argumentative flags should not be initialized as undefined,
                // instead, make a reference to array of 1024 u8s
                .value = .{ .Argumentative = [_:0]u8{0} ** 1024},
                .desc = "Path to file",
            }
    },
};
