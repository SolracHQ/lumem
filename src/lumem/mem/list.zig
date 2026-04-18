//! EntryList wraps an ordered collection of `Entry` objects and exposes Lua
//! indexing, length, and string formatting.

pub const List = @This();

const std = @import("std");
const zua = @import("zua");

const Entry = @import("entry.zig");
const Selector = @import("filter.zig").Selector;

pub const ZUA_META = zua.Meta.List(List, getElements, .{
    .__gc = deinit,
    .__tostring = display,
    .filter = filter,
    .set = set,
});

entries: std.ArrayList(zua.Object(Entry)),

fn getElements(self: *List) []zua.Object(Entry) {
    return self.entries.items;
}

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

/// Formats the list for Lua `tostring()`.
fn display(ctx: *zua.Context, self: *List) ![]const u8 {
    const fmt = "EntryList({d} entries)";
    return std.fmt.allocPrint(ctx.arena(), fmt, .{self.entries.items.len}) catch ctx.failTyped([]const u8, "Out of memory");
}

pub fn filter(ctx: *zua.Context, self: *List, selector: Selector) !List {
    var result = std.ArrayList(Entry).empty;
    errdefer result.deinit(ctx.arena());

    for (self.entries.items) |entry| {
        if (try entry.get().matches(ctx, selector)) {
            try result.append(ctx.arena(), entry.get().*);
        }
    }

    return try init(ctx, result.items);
}

pub fn set(ctx: *zua.Context, self: *List, value: zua.Decoder.Primitive) !void {
    for (self.entries.items) |entry| {
        try Entry.set(ctx, entry.get(), value);
    }
}

/// Frees the `EntryList` and its owned entry objects when Lua garbage-collects it.
fn deinit(ctx: *zua.Context, self: *List) void {
    for (self.entries.items) |entry| {
        entry.release();
    }
    self.entries.deinit(ctx.heap());
}
