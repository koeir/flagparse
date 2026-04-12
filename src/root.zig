const std = @import("std");

pub const FlagErrs = error {
    NoArgs,
    NoSuchFlag,
    FlagNotSwitch,      // non-switch/non-bool Flag treated as a switch/bool
    FlagNotArg,         // non-argumentative flag treated as an argumentative
    DuplicateFlag,
    ArgNoArg,           // no argument given to argumentative flag
    ArgTooLong,
};

const FlagFmt = enum {
    Long, Short,
};

const FlagType = enum {
    Switch, Argumentative
};

const FlagVal = union(FlagType) {
    Switch: bool,                   // On/off
    Argumentative: [1024:0]u8, // Takes an argument
    
    pub fn format(
        self: @This(),
        writer: *std.Io.Writer,
    ) std.Io.Writer.Error!void {
        switch (self) {
            .Switch => |val| try writer.print("{}", .{ val }),
            .Argumentative => |val| try writer.print("{s}", .{ val }),
        }
    }
};

pub const Flags = struct {
    const Self = @This();

    list: []const Flag,
    
    // returns null if not found
    pub fn get(self: *const Self, name: []const u8) ?*const Flag {
        return for (self.list) |flag| {
            if (std.mem.eql(u8, flag.name, name)) break &flag;
        } else null;
    }

    // errs if not found
    pub fn try_get(self: *const Self, name: []const u8) FlagErrs!*const Flag {
        return for (self.list) |flag| {
            if (std.mem.eql(u8, flag.name, name)) break &flag;
        } else FlagErrs.NoSuchFlag;
    }

    pub fn get_value(self: *const Self, comptime name: []const u8, comptime T: type) FlagErrs!T {
        const flag = try try_get(self, name);

        return switch (flag.value) {
            .Switch => |val| {
                if (@TypeOf(val) != T) { 
                    @panic(
                        "type provided does not match the retrieved flag's type\n" ++
                        "hint: tried to retrieve the value of '" ++ name ++ "' as '" ++ @typeName(T) ++
                        "' when '" ++ name ++ "' is '" ++ @typeName(@TypeOf(val)) ++ "'"
                    ); 
                }
                return val;
            },
            .Argumentative => |val| {
                if (@TypeOf(val) != T) { 
                    @panic(
                        "type provided does not match the retrieved flag's type\n" ++
                        "hint: tried to retrieve the value of '" ++ name ++ "' as '" ++ @typeName(T) ++
                        "' when '" ++ name ++ "' is '" ++ @typeName(@TypeOf(val)) ++ "'"
                    ); 
                }
                return val;
            }
        };
    }

    pub fn format(
        self: @This(),
        writer: *std.Io.Writer,
    ) std.Io.Writer.Error!void {
        for (self.list) |flag| {
            try writer.print("{f}\n", .{ flag } );
        }
    }
};

pub const Flag = struct {
    const Self = @This();

    name:   []const u8,
    long:   ?[]const u8,
    short:  ?u8,
    value:  FlagVal,
    desc:   ?[]const u8,

    // Toggles value of Switch type flag
    pub fn toggle(self: *Flag) !void {
        switch (self.value) {
            .Switch => |*val| val.* = !val.*,
            else    => |_| return FlagErrs.FlagNotSwitch,
        }
    }

    pub fn set_arg(self: *Flag, arg: []const u8) !void {
        switch (self.value) {
            .Switch => |_| return FlagErrs.FlagNotArg,
            .Argumentative => |*val| {
                if (arg.len > 1024) return FlagErrs.ArgTooLong;
                @memcpy(val[0..arg.len], arg);
            }
        }
    }

    // Pass on the init Flags struct
    pub fn isDefault(self: *const Self, comptime defaults: Flags) !bool {
        const default = try defaults.try_get(self.name);

        switch (self.value) {
            .Switch => |val| {
                return (val == default.value.Switch);
            },

            .Argumentative => |val| {
                const default_val: []const u8 =  switch (default.value) {
                    .Argumentative => |v| &v,
                    else => unreachable,
                };

                return std.mem.eql(u8, &val, default_val);
            },
        }
    }

    pub fn format(
        self: @This(),
        writer: *std.Io.Writer,
    ) std.Io.Writer.Error!void {
        var padding: usize = 30;

        if (self.short) |short| {
            try writer.print("-{c}", .{ short });

            switch (self.value) {
                .Argumentative => {
                    try writer.print(" <{s}>", .{ self.name });
                    padding -= self.name.len + 3;
                },
                else => {},
            }

            padding -= 2;

            if (self.long) |_| {
                try writer.writeAll(", ");
                padding -= 2;
            }
        }

        if (self.long) |long| {
            try writer.print("--{s}", .{ long });
            switch (self.value) {
                .Argumentative => {
                    try writer.print(" <{s}>", .{ self.name });
                    padding -= self.name.len + 3;
                },
                else => {},
            }
            padding -= long.len + 2;
        }

        while (padding > 0) : (padding -= 1) {
            try writer.writeAll(" ");
        }

        if (self.desc) |desc| try writer.writeAll(desc);
    }
};

pub const ParseConfig = struct {
    AllowDups: bool = false,
    verbose: bool = false,
    writer: ?*std.io.Writer = null,
};

// arg.index is not reset when unsuccessful
pub fn parse(
    args: *std.process.ArgIteratorPosix,
    comptime init_flags: Flags,
    out_flags: []Flag,
    cfg: ParseConfig,
    ) !Flags {

    // Should be compile error really but out_flags must be a runtime var
    if (out_flags.len != init_flags.list.len) {
        @panic("Size of parse result array must match size of init flags array");
    }

    if (cfg.verbose == true and cfg.writer == null) {
        @panic("Verbose is set to true and yet no writer is given");
    }

    // Initialize the output flags for mutation
    for (init_flags.list, 0..) |value, i| {
        out_flags[i] = value;
    }

    if (!args.skip()) return error.NoArgs;
    while (args.next()) |*arg| {
        const fmt: FlagFmt = flagfmt(arg.*) orelse continue;

        switch (fmt) {
            .Short  => try parse_chain(args, out_flags, init_flags, cfg),
            .Long   => try parse_long(args, out_flags, init_flags, cfg),
        }
    }

    // Reset the iterator when successful
    args.index = 0;

    return Flags {
        .list = out_flags,
    };
}

// Finds and sets the values for flags that have been called in long form
fn parse_long(args: *std.process.ArgIteratorPosix, flags: []Flag, comptime defaults: Flags, cfg: ParseConfig) !void {
    const flag_arg: [:0]u8 = std.mem.sliceTo(std.os.argv[args.index - 1], 0)[2..:0];
    var flag: *Flag = try get_long_flag(flags, flag_arg, cfg);

    try checkdup(flag, defaults, FlagFmt.Long, cfg);

    switch (flag.value) {
        .Switch => |_| {
            // Toggle if not dup
            try flag.toggle();
        },

        .Argumentative => |_| {
            const next_arg = args.next() orelse {
                return FlagErrs.ArgNoArg;
            };

            try check_nextarg(flag, next_arg, FlagFmt.Long, cfg);

            try flag.set_arg(next_arg);
        },
    }
}

// Same thing but for short flags + chained
fn parse_chain(args: *std.process.ArgIteratorPosix, flags: []Flag, comptime defaults: Flags, cfg: ParseConfig) !void {
    const chain: [:0]u8 = std.mem.sliceTo(std.os.argv[args.index - 1], 0)[1..:0];

    for (chain) |c| {
        var flag: *Flag = try get_short_flag(flags, c, cfg);

        try checkdup(flag, defaults, FlagFmt.Short, cfg);

        switch (flag.value) {
            .Switch => |_| {
                try flag.toggle();
            },

            .Argumentative => |_| { 
                const next_arg = args.next() orelse {
                    return FlagErrs.ArgNoArg;
                };

                try check_nextarg(flag, next_arg, FlagFmt.Short, cfg);

                try flag.set_arg(next_arg);
        },
        }
    }
}

fn check_nextarg(flag: *const Flag, arg: []const u8, fmt: FlagFmt, cfg: ParseConfig) !void {
    if (arg[0] != '-') return;
    if (!cfg.verbose) return FlagErrs.ArgNoArg;

    try cfg.writer.?.print("No valid argument supplied for: ", .{});
    switch (fmt) {
        .Long => try cfg.writer.?.print("--{s}\n", .{ flag.long.? }),
        .Short => try cfg.writer.?.print("-{c}\n", .{ flag.short.? }),
    }

    return FlagErrs.ArgNoArg;
}

fn checkdup(flag: *const Flag, comptime defaults: Flags, fmt: FlagFmt, cfg: ParseConfig) !void {
    if (!try flag.isDefault(defaults)) {
        if (cfg.AllowDups) return;
        if (cfg.verbose) {
            switch (fmt) {
                .Long => try cfg.writer.?.print("{}: --{s}\n", .{ FlagErrs.DuplicateFlag, flag.long.? }),
                .Short => try cfg.writer.?.print("{}: -{c}\n", .{ FlagErrs.DuplicateFlag, flag.short.? }),
            }
        }
        return FlagErrs.DuplicateFlag;
    }
}

// Returns whether if a flag is in long or short form
// null if it is not a flag
pub fn flagfmt(arg: []const u8) ?FlagFmt {
    if (arg.len < 2) return null;
    if (arg[0] != '-') return null;

    if (arg[1] == '-') return FlagFmt.Long;
    return FlagFmt.Short;
}

pub fn get_long_flag(flags: []Flag, arg: []const u8, cfg: ParseConfig) !*Flag {
    for (flags) |*flag| {
        if (std.mem.eql(u8, flag.long orelse continue, arg)) return flag;
    }

    if (cfg.verbose) try cfg.writer.?.print("No such flag: --{s}\n", .{ arg });
    return FlagErrs.NoSuchFlag;
}

pub fn get_short_flag(flags: []Flag, arg: u8, cfg: ParseConfig) !*Flag {
    for (flags) |*flag| {
        if (arg == flag.short orelse continue) return flag;
    }

    if (cfg.verbose) try cfg.writer.?.print("No such flag: -{c}\n", .{ arg });
    return FlagErrs.NoSuchFlag;
}
