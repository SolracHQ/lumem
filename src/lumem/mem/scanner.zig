//! Memory scanning engine.
//!
//! Scans a memory region for values matching a type and selector predicate.

const std = @import("std");
const zua = @import("zua");

const Region = @import("../region/region.zig").Region;
const Memory = @import("memory.zig");
const DataType = @import("types.zig").DataType;
const Entry = @import("entry.zig").Entry;
const Selector = @import("selector.zig").Selector;

pub const Scanner = @This();

pub fn mapError(ctx: *zua.Context, comptime T: type, err: anyerror) !T {
    return switch (err) {
        error.PartialTransfer => ctx.failWithFmtTyped(T, "partial transfer", .{}),
        error.InvalidAddress => ctx.failWithFmtTyped(T, "invalid address", .{}),
        error.InvalidArgument => ctx.failWithFmtTyped(T, "invalid argument", .{}),
        error.OutOfMemory => ctx.failWithFmtTyped(T, "out of memory", .{}),
        error.PermissionDenied => ctx.failWithFmtTyped(T, "access denied", .{}),
        error.NoSuchProcess => ctx.failWithFmtTyped(T, "no such process", .{}),
        else => ctx.failWithFmtTyped(T, "unexpected error: {s}", .{@errorName(err)}),
    };
}

pub fn scanRegion(ctx: *zua.Context, info: *const Region, dataType: DataType, selector: Selector) ![]Entry {
    if (!info.perms.value.has(.read)) {
        try ctx.failWithFmt("region at {x} is not readable", .{info.start.value});
    }

    var result = std.ArrayList(Entry).empty;
    errdefer result.deinit(ctx.arena());
    switch (dataType) {
        .Aggregated => |agg| {
            const types = agg.types();
            for (types) |typeInfo| {
                const entries = try scanRegion(ctx, info, .{ .Simple = typeInfo }, selector);
                try result.appendSlice(ctx.arena(), entries);
            }
        },
        .Simple => |simple| {
            switch (simple) {
                .u8 => try result.appendSlice(ctx.arena(), try lookFor(u8, ctx, info, selector)),
                .u16 => try result.appendSlice(ctx.arena(), try lookFor(u16, ctx, info, selector)),
                .u32 => try result.appendSlice(ctx.arena(), try lookFor(u32, ctx, info, selector)),
                .u64 => try result.appendSlice(ctx.arena(), try lookFor(u64, ctx, info, selector)),
                .i8 => try result.appendSlice(ctx.arena(), try lookFor(i8, ctx, info, selector)),
                .i16 => try result.appendSlice(ctx.arena(), try lookFor(i16, ctx, info, selector)),
                .i32 => try result.appendSlice(ctx.arena(), try lookFor(i32, ctx, info, selector)),
                .i64 => try result.appendSlice(ctx.arena(), try lookFor(i64, ctx, info, selector)),
                .f32 => try result.appendSlice(ctx.arena(), try lookFor(f32, ctx, info, selector)),
                .f64 => try result.appendSlice(ctx.arena(), try lookFor(f64, ctx, info, selector)),
                .str => try result.appendSlice(ctx.arena(), try lookForString(ctx, info, selector)),
            }
        },
    }
    return result.items;
}

fn lookFor(comptime T: type, ctx: *zua.Context, info: *const Region, selector: Selector) ![]Entry {
    var out = std.ArrayList(Entry).empty;
    var buffer: [1024 * 64 / @sizeOf(T)]T = undefined;
    var cursor = alignTo(info.start.value, T);
    while (cursor < alignTo(info.end.value, T)) {
        const toRead = @min(buffer.len, info.end.value - cursor);
        const slice = buffer[0 .. toRead / @sizeOf(T)];
        Memory.readTyped(T, ctx, info.pid.value, cursor, slice) catch |err| return mapError(ctx, []Entry, err);
        for (slice, 0..) |value, idx| {
            if (try selector.matches(T, ctx, value, null)) {
                try out.append(ctx.arena(), Entry{
                    .address = cursor + idx * @sizeOf(T),
                    .value = .from(T, value),
                    .perms = info.perms.value,
                    .pid = info.pid.value,
                });
            }
        }
        cursor += @sizeOf(T) * slice.len;
    }
    return out.items;
}

fn lookForString(ctx: *zua.Context, info: *const Region, selector: Selector) ![]Entry {
    const max_len: usize = 80;
    const target_len = selector.resolveTargetLen(ctx) catch max_len;
    if (target_len > max_len) return ctx.failWithFmtTyped([]Entry, "string too long (max {d} bytes)", .{max_len});
    if (target_len == 0) return &.{};

    var out = std.ArrayList(Entry).empty;
    var buf: [1024 * 64]u8 = undefined;
    var overlap: [80]u8 = undefined;
    var overlap_len: usize = 0;
    var cursor = info.start.value;

    while (cursor < info.end.value) {
        const to_read = @min(buf.len, info.end.value - cursor);
        Memory.readTyped(u8, ctx, info.pid.value, cursor, buf[0..to_read]) catch |err| return mapError(ctx, []Entry, err);

        var window: []const u8 = undefined;
        if (overlap_len > 0) {
            var combined: [1024 * 64 + 80]u8 = undefined;
            std.mem.copyForwards(u8, combined[0..overlap_len], overlap[0..overlap_len]);
            std.mem.copyForwards(u8, combined[overlap_len..][0..to_read], buf[0..to_read]);
            window = combined[0 .. overlap_len + to_read];
        } else {
            window = buf[0..to_read];
        }

        var pos: usize = 0;
        while (pos + target_len <= window.len) : (pos += 1) {
            const chunk = window[pos..][0..target_len];
            if (try selector.matchesString(ctx, chunk, null)) {
                const addr = cursor + pos - overlap_len;
                const owned = try ctx.heap().dupe(u8, chunk);
                try out.append(ctx.arena(), Entry{
                    .address = addr,
                    .value = Entry.Value{ .str = owned },
                    .perms = info.perms.value,
                    .pid = info.pid.value,
                });
            }
        }

        overlap_len = @min(target_len - 1, to_read);
        if (overlap_len > 0) {
            std.mem.copyForwards(u8, overlap[0..overlap_len], buf[to_read - overlap_len .. to_read]);
        }
        cursor += to_read;
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
