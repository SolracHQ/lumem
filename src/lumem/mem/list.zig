//! EntryList wraps an ordered collection of `Entry` objects and exposes Lua
//! indexing, length, and string formatting.

pub const List = @This();

const std = @import("std");
const zua = @import("zua");

const Entry = @import("entry.zig");

pub const ZUA_META = zua.Meta.Object(List, .{
    .__index = get,
    .__gc = deinit,
    .__len = len,
    .__tostring = display,
    .get = get,
});

entries: std.ArrayList(zua.Object(Entry)),

/// Constructs a new `EntryList` from a slice of `Entry` values.
pub fn init(ctx: *zua.Context, elements: []Entry) !List {
    var list = List{
        .entries = std.ArrayList(zua.Object(Entry)).empty,
    };
    for (elements) |entry| {
        try list.entries.append(ctx.heap(), zua.Object(Entry).create(ctx.state, entry).takeOwnership());
    }
    return list;
}

/// Returns the entry at the 1-based Lua index, or `nil` when out of range.
fn get(self: *List, index: usize) ?zua.Object(Entry) {
    if (index == 0) return null;
    if (index - 1 < self.entries.items.len) {
        return self.entries.items[index - 1];
    }
    return null;
}

/// Returns the number of entries in the list.
fn len(self: *List, _: *List) usize {
    return self.entries.items.len;
}

/// Formats the list for Lua `tostring()`.
fn display(ctx: *zua.Context, self: *List) ![]const u8 {
    const fmt = "EntryList({d} entries)";
    return std.fmt.allocPrint(ctx.arena(), fmt, .{self.entries.items.len}) catch ctx.failTyped([]const u8, "Out of memory");
}

/// Frees the `EntryList` and its owned entry objects when Lua garbage-collects it.
fn deinit(ctx: *zua.Context, self: *List) void {
    for (self.entries.items) |entry| {
        entry.release();
    }
    self.entries.deinit(ctx.heap());
}
