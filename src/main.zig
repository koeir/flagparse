const std = @import("std");
const flag = @import("flagparse");

pub fn main() !void {
    var stdout_buf: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buf);
    const stdout = &stdout_writer.interface;
    defer stdout.flush() catch {};

    var flaggar: [initflags.len]flag.Flag = undefined;
    for (initflags, 0..) |f, i| {
        flaggar[i] = f;
    }

    const flaggot: flag.Flags = .{
        .list = &flaggar,
    };

    for (flaggot.list) |f| {
        try stdout.print("{f}\n", .{ f });
    }

    flaggar[0] = flag.Flag {
        .name = "test",
        .long = "test",
        .short = 'r',
        .opt = true,
        .value = .{ .Switch = false },
        .desc = "Recurse into directories",
    };

    for (flaggot.list) |f| {
        try stdout.print("{f}\n", .{ f });
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
        .value = .{.Argumentative = undefined },
        .desc = "Path to file",
    }
};
