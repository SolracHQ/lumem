//! ProcList wraps an ordered collection of Process objects.
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

const methods = .{
    .__gc = deinit,
    .__tostring = display,
    .filter = zua.Native.new(filter, .{}, .{
        .description = "Keeps only processes matching the given criteria, removing the rest.",
        .args = &.{
            .{ .name = "filter", .description = "Filter with pid, uid, name, or cmdLine fields." },
        },
    }),
    .clone = zua.Native.new(clone, .{}, .{
        .description = "Returns a new list with the same processes.",
    }),
    .scan = zua.Native.new(scan, .{}, .{
        .description = "Scans all processes in the list for matching memory values.",
        .args = &.{
            .{ .name = "dataType", .description = "Data type to scan for." },
            .{ .name = "selector", .description = "Comparison predicate table." },
            .{ .name = "filter", .description = "Optional permission filter." },
        },
    }),
};

pub const ZUA_META = zua.Meta.List(List, getElements, methods, .{
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
    var out = std.ArrayList(u8).empty;
    var buf: [256]u8 = undefined;
    const header = try std.fmt.bufPrint(&buf, "ProcList({d} processes)\nindex pid      name\n", .{self.processes.items.len});
    try out.appendSlice(ctx.arena(), header);
    const max_display = 20;
    for (self.processes.items, 0..) |proc, idx| {
        if (idx >= max_display) break;
        const proc_ref = proc.get();
        const row = try std.fmt.bufPrint(&buf, "{d:5} {d:8} {s}\n", .{ idx + 1, @as(u64, @abs(proc_ref.pid)), proc_ref.name });
        try out.appendSlice(ctx.arena(), row);
    }
    if (self.processes.items.len > max_display) {
        const tail = try std.fmt.bufPrint(&buf, "... {d} more\n", .{self.processes.items.len - max_display});
        try out.appendSlice(ctx.arena(), tail);
    }
    return out.items;
}

/// Keeps only processes matching the given criteria, removing the rest.
pub fn filter(ctx: *zua.Context, self: *List, _filter: ProcessFilter) !void {
    var write_idx: usize = 0;
    for (self.processes.items) |proc| {
        if (_filter.matches(proc.get())) {
            self.processes.items[write_idx] = proc;
            write_idx += 1;
        } else {
            proc.release();
        }
    }
    self.processes.shrinkAndFree(ctx.heap(), write_idx);
}

/// Returns a new list with copies of the same processes.
pub fn clone(ctx: *zua.Context, self: *List) !List {
    var out = std.ArrayList(zua.Object(Process)).empty;
    errdefer out.deinit(ctx.heap());

    for (self.processes.items) |proc| {
        const owned = proc.owned();
        errdefer owned.release();
        try out.append(ctx.heap(), owned);
    }

    return List{ .processes = out };
}

/// Scans all processes in the list for matching memory values.
pub fn scan(ctx: *zua.Context, self: *List, dataType: DataType, selector: Selector, _filter: ?Region.Permissions) !EntryList {
    const region_filter = _filter orelse try Region.Permissions.fromString(ctx, "rw--");

    var entries = std.ArrayList(Entry).empty;
    errdefer entries.deinit(ctx.arena());

    for (self.processes.items) |proc| {
        const regions = try RegionScanner.scan(ctx, proc.get().pid, region_filter);
        defer for (regions) |*region| {
            Region.cleanup(ctx, region);
        };
        for (regions) |*region| {
            const region_entries = try MemScanner.scanRegion(ctx, region, dataType, selector);
            try entries.appendSlice(ctx.arena(), region_entries);
        }
    }

    return try EntryList.init(ctx, entries.items);
}

test {
    std.testing.refAllDecls(@This());
}
