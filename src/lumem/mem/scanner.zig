//! Scans a memory region for values matching a type and selector predicate.
//!
//! Returns the matching entries for values that pass the selector in the
//! given region. Supports both fixed-size types and aggregated type families.

const std = @import("std");

const Region = @import("../region/region.zig");
const DataType = @import("../mem/types.zig").DataType;
const Entry = @import("../mem/entry.zig").Entry;
const Selector = @import("../mem/selector.zig").Selector;
const Memory = @import("./memory.zig");

const zua = @import("zua");

pub const Scanner = @This();

/// Scans a memory region for values matching a type and selector predicate.
pub fn scanRegion(ctx: *zua.Context, region: Region, dataType: DataType, selector: Selector) ![]Entry {
    if (!region.perms.has(.read)) {
        try ctx.failWithFmt("region at {x} is not readable", .{region.start});
    }

    var result = std.ArrayList(Entry).empty;
    errdefer result.deinit(ctx.arena());
    switch (dataType) {
        .Aggregated => |agg| {
            const types = agg.types();
            for (types) |typeInfo| {
                const entries = try scanRegion(ctx, region, .{ .Simple = typeInfo }, selector);
                try result.appendSlice(ctx.arena(), entries);
            }
        },
        .Simple => |simple| {
            switch (simple) {
                .u8 => try result.appendSlice(ctx.arena(), try lookForT(u8, ctx, region, selector)),
                .u16 => try result.appendSlice(ctx.arena(), try lookForT(u16, ctx, region, selector)),
                .u32 => try result.appendSlice(ctx.arena(), try lookForT(u32, ctx, region, selector)),
                .u64 => try result.appendSlice(ctx.arena(), try lookForT(u64, ctx, region, selector)),
                .i8 => try result.appendSlice(ctx.arena(), try lookForT(i8, ctx, region, selector)),
                .i16 => try result.appendSlice(ctx.arena(), try lookForT(i16, ctx, region, selector)),
                .i32 => try result.appendSlice(ctx.arena(), try lookForT(i32, ctx, region, selector)),
                .i64 => try result.appendSlice(ctx.arena(), try lookForT(i64, ctx, region, selector)),
                .f32 => try result.appendSlice(ctx.arena(), try lookForT(f32, ctx, region, selector)),
                .f64 => try result.appendSlice(ctx.arena(), try lookForT(f64, ctx, region, selector)),
            }
        },
    }
    return result.items;
}

fn lookForT(comptime T: type, ctx: *zua.Context, region: Region, selector: Selector) ![]Entry {
    var out = std.ArrayList(Entry).empty;
    var buffer: [1024 * 64 / @sizeOf(T)]T = undefined;
    var cursor = alignTo(region.start, T);
    while (cursor < alignTo(region.end, T)) {
        const toRead = @min(buffer.len, region.end - cursor);
        const slice = buffer[0 .. toRead / @sizeOf(T)];
        try Memory.readTyped(T, ctx, region.pid, cursor, slice);
        for (slice, 0..) |value, idx| {
            if (try selector.matches(T, ctx, value, null)) {
                try out.append(ctx.arena(), Entry{
                    .address = cursor + idx * @sizeOf(T),
                    .value = .from(T, value),
                    .perms = region.perms,
                    .pid = region.pid,
                });
            }
        }
        cursor += @sizeOf(T) * slice.len;
    }
    return out.items;
}

fn alignTo(address: usize, comptime T: type) usize {
    const alignment = @alignOf(T);
    const misalignment = address % alignment;
    if (misalignment == 0) return address;
    return address + (alignment - misalignment);
}

test {
    std.testing.refAllDecls(@This());
}
