//! ProcList wraps an ordered collection of `Process` objects.
//! It is returned from `lumem:scan()` and supports Lua indexing,
//! length queries, and string formatting.

const std = @import("std");
const zua = @import("zua");

const Process = @import("process.zig");
const ProcessFilter = @import("filter.zig").Filter;
const Region = @import("../region/region.zig");
const RegionScanner = @import("../region/scanner.zig");
const MemScanner = @import("../mem/scanner.zig");
const Entry = @import("../mem/entry.zig");
const EntryList = @import("../mem/list.zig").List;
const DataType = @import("../mem/types.zig").DataType;
const Selector = @import("../mem/selector.zig").Selector;

pub const List = @This();

pub const ZUA_META = zua.Meta.List(List, getElements, .{
    .__gc = deinit,
    .__tostring = display,
    .filter = filter,
    .scan = scan,
}, .{
    .name = "ProcList",
    .description = "A collection of Process objects returned by lumem:scan().",
});


processes: std.ArrayList(zua.Object(Process)),

fn getElements(self: *List) []zua.Object(Process) {
    return self.processes.items;
}


/// Constructs a new ProcList from a slice of process values.
pub fn init(ctx: *zua.Context, elements: []Process) !List {
    var list = List{
        .processes = std.ArrayList(zua.Object(Process)).empty,
    };
    for (elements) |proc| {
        try list.processes.append(ctx.heap(), zua.Object(Process).create(ctx.state, proc).takeOwnership());
    }
    return list;
}

fn deinit(ctx: *zua.Context, self: *List) void {
    for (self.processes.items) |proc| {
        proc.release();
    }
    self.processes.deinit(ctx.heap());
}


/// Formats the list for Lua tostring().
fn display(ctx: *zua.Context, self: *List) ![]const u8 {
    const fmt = "ProcList({d} processes)";
    return std.fmt.allocPrint(ctx.arena(), fmt, .{self.processes.items.len}) catch ctx.failTyped([]const u8, "Out of memory");
}

pub fn filter(ctx: *zua.Context, self: *List, _filter: ProcessFilter) !List {
    var result = std.ArrayList(Process).empty;
    errdefer result.deinit(ctx.arena());

    for (self.processes.items) |proc| {
        if (_filter.matches(proc.get())) {
            try result.append(ctx.arena(), proc.get().*);
        }
    }

    return try init(ctx, result.items);
}

pub fn scan(ctx: *zua.Context, self: *List, dataType: DataType, selector: Selector, _filter: ?Region.Permissions) !EntryList {
    const region_filter = _filter orelse try Region.Permissions.fromString(ctx, "rw--");

    var entries = std.ArrayList(Entry).empty;
    errdefer entries.deinit(ctx.arena());

    for (self.processes.items) |proc| {
        const regions = try RegionScanner.scan(ctx, proc.get().pid, region_filter);
        defer for (regions) |*region| {
            Region.cleanup(ctx, region);
        };
        for (regions) |region| {
            const region_entries = try MemScanner.scanRegion(ctx, region, dataType, selector);
            try entries.appendSlice(ctx.arena(), region_entries);
        }
    }

    return try EntryList.init(ctx, entries.items);
}

test {
    std.testing.refAllDecls(@This());
}
