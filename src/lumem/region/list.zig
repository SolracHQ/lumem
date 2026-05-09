//! RegionList wraps an ordered collection of Region objects and exposes Lua
//! indexing, length, and string formatting.

const std = @import("std");
const zua = @import("zua");
const Region = @import("region.zig");
const Entry = @import("../mem/entry.zig");
const EntryList = @import("../mem/list.zig").List;
const Scanner = @import("../mem/scanner.zig");
const DataType = @import("../mem/types.zig").DataType;
const Selector = @import("../mem/selector.zig").Selector;
const Permissions = @import("perms.zig");

pub const List = @This();

const methods = .{
    .__gc = deinit,
    .__tostring = display,
    .scan = zua.Native.new(scan, .{}, .{
        .description = "Scans all regions in the list for matching memory values.",
        .args = &.{
            .{ .name = "dataType", .description = "Data type to scan for." },
            .{ .name = "selector", .description = "Comparison predicate table." },
        },
    }),
};

pub const ZUA_META = zua.Meta.List(List, getElements, methods, .{
    .name = "RegionList",
    .description = "A collection of Region objects returned by process:regions().",
});

regions: std.ArrayList(zua.Object(Region)),

fn getElements(self: *List) []zua.Object(Region) {
    return self.regions.items;
}

/// Constructs a new RegionList from a slice of Region values.
pub fn init(ctx: *zua.Context, elements: []Region) !List {
    var list = List{
        .regions = std.ArrayList(zua.Object(Region)).empty,
    };
    errdefer {
        for (list.regions.items) |r| r.release();
        list.regions.deinit(ctx.heap());
    }
    for (elements) |region| {
        try list.regions.append(ctx.heap(), zua.Object(Region).create(ctx.state, region).takeOwnership());
    }
    return list;
}

fn deinit(ctx: *zua.Context, self: *List) void {
    for (self.regions.items) |region| {
        region.release();
    }
    self.regions.deinit(ctx.heap());
}

/// Formats the list for Lua tostring().
fn display(ctx: *zua.Context, self: *List) ![]const u8 {
    var out = std.ArrayList(u8).empty;
    var buf: [256]u8 = undefined;
    const header = try std.fmt.bufPrint(&buf, "RegionList({d} regions)\nindex start              end                 perms pathname\n", .{self.regions.items.len});
    try out.appendSlice(ctx.arena(), header);
    const max_display = 20;
    for (self.regions.items, 0..) |region, idx| {
        if (idx >= max_display) break;
        const region_ref = region.get();
        const perms_str = try Permissions.display(ctx, region_ref.perms);
        const row = try std.fmt.bufPrint(&buf, "{d:5} 0x{x:0>16}-0x{x:0>16}  {s}  {s}\n", .{ idx + 1, region_ref.start, region_ref.end, perms_str, region_ref.pathname });
        try out.appendSlice(ctx.arena(), row);
    }
    if (self.regions.items.len > max_display) {
        const tail = try std.fmt.bufPrint(&buf, "... {d} more\n", .{self.regions.items.len - max_display});
        try out.appendSlice(ctx.arena(), tail);
    }
    return out.items;
}

/// Scans all regions in the list for matching memory values.
pub fn scan(ctx: *zua.Context, self: *List, dataType: DataType, selector: Selector) !EntryList {
    var entries = std.ArrayList(Entry).empty;
    errdefer entries.deinit(ctx.arena());

    for (self.regions.items) |region| {
        const region_entries = try Scanner.scanRegion(ctx, region.get(), dataType, selector);
        try entries.appendSlice(ctx.arena(), region_entries);
    }

    return try EntryList.init(ctx, entries.items);
}

test {
    std.testing.refAllDecls(@This());
}
