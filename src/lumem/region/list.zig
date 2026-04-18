//! RegionList wraps an ordered collection of `Region` objects and exposes Lua
//! indexing, length, and string formatting.

pub const List = @This();

const std = @import("std");
const zua = @import("zua");
const Region = @import("region.zig");
const Entry = @import("../mem/entry.zig");
const EntryList = @import("../mem/list.zig").List;
const Scanner = @import("../mem/scanner.zig");
const DataType = @import("../mem/data_type.zig").DataType;
const Selector = @import("../mem/filter.zig").Selector;

pub const ZUA_META = zua.Meta.List(List, getElements, .{
    .__gc = deinit,
    .__tostring = display,
    .scan = scan,
});

regions: std.ArrayList(zua.Object(Region)),

fn getElements(self: *List) []zua.Object(Region) {
    return self.regions.items;
}

/// Constructs a new `RegionList` from a slice of `Region` values.
pub fn init(ctx: *zua.Context, elements: []Region) !List {
    var list = List{
        .regions = std.ArrayList(zua.Object(Region)).empty,
    };
    for (elements) |region| {
        try list.regions.append(ctx.heap(), zua.Object(Region).create(ctx.state, region).takeOwnership());
    }
    return list;
}

/// Formats the list for Lua `tostring()`.
fn display(ctx: *zua.Context, self: *List) ![]const u8 {
    const fmt = "RegionList({d} regions)";
    return std.fmt.allocPrint(ctx.arena(), fmt, .{self.regions.items.len}) catch ctx.failTyped([]const u8, "Out of memory");
}

pub fn scan(ctx: *zua.Context, self: *List, dataType: DataType, selector: Selector) !EntryList.List {
    var entries = std.ArrayList(Entry).empty;
    errdefer entries.deinit(ctx.arena());

    for (self.regions.items) |region| {
        const region_entries = try Scanner.scanRegion(ctx, region.get().*, dataType, selector);
        try entries.appendSlice(ctx.arena(), region_entries);
    }

    return try EntryList.init(ctx, entries.items);
}

/// Frees the `RegionList` and its owned region objects when Lua garbage-collects it.
fn deinit(ctx: *zua.Context, self: *List) void {
    for (self.regions.items) |region| {
        region.release();
    }
    self.regions.deinit(ctx.heap());
}
