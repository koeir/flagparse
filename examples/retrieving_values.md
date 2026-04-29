```zig
const defaults = @import("./init_flags.zig").defaults;
const Flags = zigflag.StructFlags(defaults);

pub fn main(init: std.process.Init) !void {
    ...
    const parsed: Flags = result.flags;
    // arg list that has flags removed;
    // also removes values that were taken in by flags
    const flagless_args: [][:0]const u8 = result.args;

    if (parsed.force) // whatever

    const recursive: bool = parsed.recursive;
    const files: ?[][:0]const u8 = parsed.files;

    if (!recursive) //whatever

    for (files orelse &.{}) |file| {
        // whatever
    }
    ...
}
```
