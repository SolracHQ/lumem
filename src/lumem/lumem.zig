//! Lumem is the root scripting object exposed to Lua as the global `lumem`.
//! It provides access to live process enumeration and other host-side utilities
//! for scripts and the interactive REPL.

const zua = @import("zua");
const Meta = zua.Meta;
const Process = @import("proc/proc.zig");

/// The top-level `lumem` object available in Lua.
///
/// Example:
/// ```lua
/// local processes = lumem:scan({ name = "target" })
/// ```
const Lumem = @This();

pub const ZUA_META = Meta.Object(Lumem, .{
    .scan = scan,
});

/// Scans live processes and returns a `Process.List` wrapper.
///
/// The optional `filter` argument may include fields such as `pid`, `uid`,
/// `name`, and `cmdLine` to limit the returned processes.
///
/// Lua usage:
/// ```lua
/// local processes = lumem:scan({ name = "target" })
/// ```
fn scan(ctx: *zua.Context, _: *Lumem, filter: ?Process.Filter) !Process.List {
    const _filter = filter orelse Process.Filter{};
    const procs = try Process.Scanner.scan(ctx, &_filter);
    return try Process.List.init(ctx, procs);
}
