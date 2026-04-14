//! RegionList wraps an ordered collection of `Region` objects and exposes Lua
//! indexing, length, and string formatting.

pub const List = @This();

const std = @import("std");
const zua = @import("zua");
const Region = @import("region.zig");

pub const ZUA_META = zua.Meta.Object(List, .{
    .__gc = deinit,
    .__index = get,
    .__len = len,
    .__tostring = display,
    .get = get,
});

regions: std.ArrayList(zua.Object(Region)),

/// Constructs a new `RegionList` from a slice of `Region` values.
pub fn init(ctx: *zua.Context, elements: []Region) !List {
    var list = List{
        .regions = std.ArrayList(zua.Object(Region)).empty,
    };
    for (elements) |region| {
        try list.regions.append(ctx.state.allocator, zua.Object(Region).create(ctx.state, region).takeOwnership());
    }
    return list;
}

/// Returns the region at the 1-based Lua index, or `nil` when out of range.
fn get(self: *List, index: usize) ?zua.Object(Region) {
    if (index == 0) return null;
    if (index - 1 < self.regions.items.len) {
        return self.regions.items[index - 1];
    }
    return null;
}

/// Returns the number of regions in the list.
fn len(self: *List, _: *List) usize {
    return self.regions.items.len;
}

/// Formats the list for Lua `tostring()`.
fn display(ctx: *zua.Context, self: *List) ![]const u8 {
    const fmt = "RegionList({d} regions)";
    return std.fmt.allocPrint(ctx.allocator(), fmt, .{self.regions.items.len}) catch ctx.failTyped([]const u8, "Out of memory");
}

/// Frees the `RegionList` and its owned region objects when Lua garbage-collects it.
fn deinit(ctx: *zua.Context, self: *List) void {
    for (self.regions.items) |region| {
        region.release();
    }
    self.regions.deinit(ctx.state.allocator);
}
