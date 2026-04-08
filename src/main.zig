const std = @import("std");
const flag = @import("flagparse");

pub fn main() !void {
    var stdout_buf: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buf);
    const stdout = &stdout_writer.interface;
    defer stdout.flush() catch {};

    var args: std.process.ArgIteratorPosix = .init();

    var flagarr: [initflags.list.len]flag.Flag = undefined;
    const flags = try flag.parse(&args, initflags, &flagarr, .{ .verbose = true });

    for (flags.list) |f| {
        switch (f.value) {
            .Switch => |val| {
                if (val == try initflags.get(f.name).?.switchval()) continue;
                try stdout.print("{f}\n", .{ f });
            },
            .Argumentative => |val| {
                if (std.mem.eql(u8, val, initflags.get(f.name).?.value.Argumentative)) continue;
                try stdout.print("{s}\n", .{ val });
            },
        }
    }
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
    },
};
