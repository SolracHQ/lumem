//! ProcList wraps an ordered collection of `Process` objects.
//! It is returned from `lumem:scan()` and supports Lua indexing,
//! length queries, and string formatting.

pub const List = @This();

const std = @import("std");
const zua = @import("zua");

const Process = @import("proc.zig");

pub const ZUA_META = zua.Meta.Object(List, .{
    .__index = get,
    .__gc = deinit,
    .__len = len,
    .__tostring = display,
    .get = get,
});

processes: std.ArrayList(zua.Object(Process)),

/// Constructs a new `ProcList` from a slice of process values.
pub fn init(ctx: *zua.Context, elements: []Process) !List {
    var list = List{
        .processes = std.ArrayList(zua.Object(Process)).empty,
    };
    for (elements) |proc| {
        try list.processes.append(ctx.state.allocator, zua.Object(Process).create(ctx.state, proc).takeOwnership());
    }
    return list;
}

/// Returns the process at `index` (1-based), or `nil` when out of range.
fn get(self: *List, index: usize) ?zua.Object(Process) {
    // Lua is 1-indexed ugh, but it is what it is.
    if (index == 0) {
        return null;
    }
    if (index - 1 < self.processes.items.len) {
        return self.processes.items[index - 1];
    } else {
        return null;
    }
}

/// Returns the number of processes in the list.
fn len(self: *List, _: *List) usize {
    return self.processes.items.len;
}

/// Formats the list for Lua `tostring()`.
fn display(ctx: *zua.Context, self: *List) ![]const u8 {
    const fmt = "ProcList({d} processes)";
    return std.fmt.allocPrint(ctx.allocator(), fmt, .{self.processes.items.len}) catch ctx.failTyped([]const u8, "Out of memory");
}

/// Frees the `ProcList` and its owned process objects when Lua garbage-collects it.
fn deinit(ctx: *zua.Context, self: *List) void {
    for (self.processes.items) |proc| {
        proc.release();
    }
    self.processes.deinit(ctx.state.allocator);
}
