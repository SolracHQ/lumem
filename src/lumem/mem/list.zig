//! EntryList wraps an ordered collection of Entry objects and exposes Lua
//! indexing, length, and string formatting.

const std = @import("std");
const zua = @import("zua");

const Entry = @import("entry.zig");
const Selector = @import("selector.zig").Selector;
const SimpleType = @import("types.zig").SimpleType;

pub const List = @This();

const methods = .{
    .__gc = deinit,
    .__tostring = display,
    .filter = zua.Native.new(filter, .{}, .{
        .description = "Keeps only entries matching a selector, removing the rest.",
        .args = &.{
            .{ .name = "selector", .description = "Comparison predicate table." },
        },
    }),
    .clone = zua.Native.new(clone, .{}, .{
        .description = "Returns a new list with the same entries.",
    }),
    .set = zua.Native.new(set, .{}, .{
        .description = "Writes a value to every entry in the list.",
        .args = &.{
            .{ .name = "value", .description = "Value to write to each entry's address." },
        },
    }),
    .pin = zua.Native.new(pin, .{}, .{
        .description = "Pins every entry in the list so their values stay at the written amount.",
        .args = &.{
            .{ .name = "value", .description = "Optional value to pin. Defaults to each entry's current cached value." },
        },
    }),
    .unpin = zua.Native.new(unpin, .{}, .{
        .description = "Unpins every entry in the list.",
    }),
    .__add = zua.Native.new(m_add, .{}, .{
        .description = "Merges two entry lists into a new one.",
    }),
};

pub const ZUA_META = zua.Meta.List(List, getElements, methods, .{
    .name = "EntryList",
    .description = "A collection of Entry objects returned by memory scans.",
});

entries: std.ArrayList(zua.Object(Entry)),

fn getElements(self: *List) []zua.Object(Entry) {
    return self.entries.items;
}

/// Constructs a new EntryList from a slice of Entry values.
pub fn init(ctx: *zua.Context, elements: []Entry) !List {
    var list = List{
        .entries = std.ArrayList(zua.Object(Entry)).empty,
    };
    errdefer {
        for (list.entries.items) |e| e.release();
        list.entries.deinit(ctx.heap());
    }
    for (elements) |entry| {
        try list.entries.append(ctx.heap(), zua.Object(Entry).create(ctx.state, entry).takeOwnership());
    }
    return list;
}

fn deinit(ctx: *zua.Context, self: *List) void {
    for (self.entries.items) |entry| {
        entry.release();
    }
    self.entries.deinit(ctx.heap());
}

/// Formats the list for Lua tostring().
fn display(ctx: *zua.Context, self: *List) ![]const u8 {
    var out = std.ArrayList(u8).empty;
    var buf: [256]u8 = undefined;

    var type_counts = std.EnumMap(SimpleType, usize).initFullWithDefault(0, .{});
    for (self.entries.items) |entry| {
        const tag = std.meta.activeTag(entry.get().value);
        type_counts.put(tag, (type_counts.get(tag) orelse 0) + 1);
    }
    var summary = std.ArrayList(u8).empty;
    var first = true;
    var iter = type_counts.iterator();
    while (iter.next()) |kv| {
        if (kv.value.* == 0) continue;
        if (!first) try summary.appendSlice(ctx.arena(), ", ");
        first = false;
        const line = try std.fmt.bufPrint(buf[0..], "{s} {d}", .{ @tagName(kv.key), kv.value.* });
        try summary.appendSlice(ctx.arena(), line);
    }
    try out.appendSlice(ctx.arena(), "Summary: ");
    try out.appendSlice(ctx.arena(), summary.items);

    const header = try std.fmt.bufPrint(buf[0..], "\nindex address            type live      cached\n", .{});
    try out.appendSlice(ctx.arena(), header);

    const max_display = 20;
    for (self.entries.items, 0..) |entry, idx| {
        if (idx >= max_display) break;
        const entry_ref = entry.get();
        const tag = std.meta.activeTag(entry_ref.value);
        const type_name = @tagName(tag);
        const cached_str = try entry_ref.value.display(ctx.arena());
        const live_str = readLiveDisplay(ctx, entry_ref) catch "?";
        const row = try std.fmt.bufPrint(buf[0..], "{d:5} 0x{x:0>16} {s:4} {s:9} {s:9}\n", .{ idx + 1, entry_ref.address, type_name, live_str, cached_str });
        try out.appendSlice(ctx.arena(), row);
    }

    if (self.entries.items.len > max_display) {
        const tail = try std.fmt.bufPrint(buf[0..], "... {d} more\n", .{self.entries.items.len - max_display});
        try out.appendSlice(ctx.arena(), tail);
    }

    return out.items;
}

fn readLiveDisplay(ctx: *zua.Context, entry_ref: *const Entry) ![]const u8 {
    const tag = std.meta.activeTag(entry_ref.value);
    const val = switch (tag) {
        .u8 => Entry.Value{ .u8 = try Entry.readValue(u8, ctx, entry_ref) },
        .u16 => Entry.Value{ .u16 = try Entry.readValue(u16, ctx, entry_ref) },
        .u32 => Entry.Value{ .u32 = try Entry.readValue(u32, ctx, entry_ref) },
        .u64 => Entry.Value{ .u64 = try Entry.readValue(u64, ctx, entry_ref) },
        .i8 => Entry.Value{ .i8 = try Entry.readValue(i8, ctx, entry_ref) },
        .i16 => Entry.Value{ .i16 = try Entry.readValue(i16, ctx, entry_ref) },
        .i32 => Entry.Value{ .i32 = try Entry.readValue(i32, ctx, entry_ref) },
        .i64 => Entry.Value{ .i64 = try Entry.readValue(i64, ctx, entry_ref) },
        .f32 => Entry.Value{ .f32 = try Entry.readValue(f32, ctx, entry_ref) },
        .f64 => Entry.Value{ .f64 = try Entry.readValue(f64, ctx, entry_ref) },
        .str => Entry.Value{ .str = try Entry.readStringValue(ctx, entry_ref) },
    };
    return val.display(ctx.arena());
}

/// Keeps only entries matching a selector, removing the rest.
pub fn filter(ctx: *zua.Context, self: *List, selector: Selector) !void {
    var write_idx: usize = 0;
    for (self.entries.items) |entry| {
        const is_match = entry.get().matches(ctx, selector) catch {
            ctx.err = null;
            entry.release();
            continue;
        };
        if (is_match) {
            self.entries.items[write_idx] = entry;
            write_idx += 1;
        } else {
            entry.release();
        }
    }
    self.entries.shrinkAndFree(ctx.heap(), write_idx);
}

/// Returns a new list with copies of the same entries.
pub fn clone(ctx: *zua.Context, self: *List) !List {
    var out = std.ArrayList(zua.Object(Entry)).empty;
    errdefer out.deinit(ctx.heap());

    for (self.entries.items) |entry| {
        const owned = entry.owned();
        errdefer owned.release();
        try out.append(ctx.heap(), owned);
    }

    return List{ .entries = out };
}

/// Writes a value to every entry in the list. Continues on errors, reports a summary.
pub fn set(ctx: *zua.Context, self: *List, value: zua.Decoder.Primitive) !void {
    var failures: usize = 0;
    for (self.entries.items) |entry| {
        Entry.set(ctx, entry.get(), value) catch {
            ctx.err = null;
            failures += 1;
        };
    }
    if (failures > 0) {
        return ctx.failWithFmt("wrote {d} of {d} entries ({d} failed)", .{
            self.entries.items.len - failures,
            self.entries.items.len,
            failures,
        });
    }
}

/// Pins every entry in the list so their values stay at the written amount.
pub fn pin(ctx: *zua.Context, self: *List, value: ?zua.Decoder.Primitive) !void {
    var failures: usize = 0;
    for (self.entries.items) |entry| {
        Entry.pin(ctx, entry.get(), value) catch {
            ctx.err = null;
            failures += 1;
        };
    }
    if (failures > 0) {
        return ctx.failWithFmt("pinned {d} of {d} entries ({d} failed)", .{
            self.entries.items.len - failures,
            self.entries.items.len,
            failures,
        });
    }
}

/// Unpins every entry in the list.
pub fn unpin(ctx: *zua.Context, self: *List) !void {
    var failures: usize = 0;
    for (self.entries.items) |entry| {
        Entry.unpin(ctx, entry.get()) catch {
            ctx.err = null;
            failures += 1;
        };
    }
    if (failures > 0) {
        return ctx.failWithFmt("unpinned {d} of {d} entries ({d} failed)", .{
            self.entries.items.len - failures,
            self.entries.items.len,
            failures,
        });
    }
}

fn m_add(ctx: *zua.Context, self: *List, other: *List) !List {
    var out = std.ArrayList(zua.Object(Entry)).empty;
    errdefer out.deinit(ctx.heap());

    for (self.entries.items) |entry| {
        const owned = entry.owned();
        errdefer owned.release();
        try out.append(ctx.heap(), owned);
    }
    for (other.entries.items) |entry| {
        const owned = entry.owned();
        errdefer owned.release();
        try out.append(ctx.heap(), owned);
    }

    return List{ .entries = out };
}

test {
    std.testing.refAllDecls(@This());
}
