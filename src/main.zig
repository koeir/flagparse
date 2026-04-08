const std = @import("std");
const flag = @import("flagparse");

pub fn main() !void {
    var stdout_buf: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buf);
    const stdout = &stdout_writer.interface;
    defer stdout.flush() catch {};

    var args: std.process.ArgIteratorPosix = .init();

    var flagarr: [initflags.len]flag.Flag = undefined;
    const flags = try flag.parse(&args, &initflags, &flagarr, .{ .verbose = true });

    for (flags.list) |f| {
        try stdout.print("{f}\n", .{ f });
        try stdout.writeAll("Is set to ");

        switch (f.value) {
            .Switch => |val| try stdout.print("{}\n", .{ val }),
            .Argumentative => |val| try stdout.print("{s}\n", .{ val }),
        }

        try stdout.writeAll("\n");
    }
}

// Initialize flags and their default values
// name doesn't really matter as long as the 
// members are all of type Flag
const initflags = [_]flag.Flag {
    flag.Flag {
        .name = "recursive",
        .long = "recursive",
        .short = 'r',
        .opt = true,
        .value = .{ .Switch = false },
        .desc = "Recurse into directories",
    },

    flag.Flag {
        .name = "force",
        .long = "force",
        .short = 'f',
        .opt = true,
        .value = .{ .Switch = false },
        .desc = "Skip confirmation prompts",
    },

    flag.Flag {
        .name = "file",
        .long = "path",
        .short = 'p',
        .opt = true,
        // Should not be undef
        .value = .{ .Argumentative = "" },
        .desc = "Path to file",
    }
};
