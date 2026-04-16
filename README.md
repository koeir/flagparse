# flagparse
A simple flag parser for POSIX-compliant Zig programs.

## Features
- No heap allocation
- Formatted printing
- Simple interface
- Returns argv list without flags

## Config Options
- **allowDups**: Don't error when duplicate flags are set. *Default is false*.
- **verbose**: Print out error messages when errors occur. *Default is false*.
- **prefix**: Print out a custom string for verbose messages. *Default is null*.
- **writer**: Required when using verbose option. Doesn't really do anything without it. *Default is null*.
- **allowDashAsFirstCharInArgForArg**: I admit this needs a better name. It allows argumentative type flags (meaning flags that hold a string/arg) to hold strings that begin with "-". *Default is true*.

## Usage
1. Fetch with zig and add as module in build.zig
```zsh
zig fetch --save https://github.com/koeir/flagparse/releases/tag/v0.2.1
```
```zig
    // build.zig
    const flagparse = b.dependency("flagparse", .{
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "example",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        })
    });

    exe.root_module.addImport("flagparse", flagparse.module("flagparse"));
    b.installArtifact(exe);
```

2. Declare a list of flags with the built-in structs
``` zig
const initflags: flagparse.Type.Flags = .{
    .list = &[_] flagparse.Type.Flag 
    {
        .{
            .name = "recursive",
            .long = "recursive",
            .short = 'r',
            .value = .{ .Switch = false },
            .desc = "Recurse into directories",
        },

        .{
            .name = "force",
            .long = "force",
            .short = 'f',
            .value = .{ .Switch = false },
            .desc = "Skip confirmation prompts",
        },
        .{
            .name = "file",
            .long = "path",
            .short = 'p',
            .value = .{ .Argumentative = [_:0]u8{0} ** 1024 },
            .desc = "Path to file",
        },
    },
    
};

```

3. Initialize posix argument iterator and buffers
``` zig
const std = @import("std");
const flagparse = @import("flagparse");

pub fn main() !void {
    ...
    var args: std.process.ArgIteratorPosix = .init();

    var flagarr: [initflags.list.len]flagparse.Type.Flag = undefined;
    var argbuf: [20][:0]const u8 = undefined;
    ...

```

4. Parse
``` zig
const std = @import("std");
const flagparse = @import("flagparse");

pub fn main() !void {
    ...
    var args: std.process.ArgIteratorPosix = .init();

    // buffers; must remain in scope for flags and argv
    var flagarr: [initflags.list.len]flagparse.Type.Flag = undefined;
    var argbuf: [20][:0]const u8 = undefined;

    const result = try flagparse.parse(&args, argbuf[0..], initflags, &flagarr, .{})

    // retrieve values from tuple
    const flags = result.flags;
    const argv = result.argv;
    ...

```

5. Use
```zig
    ...
    const recursive: bool = try flags.get_value("recursive", bool);
    const file = try flags.get_value("file", [1024:0]u8);
    ...
```
