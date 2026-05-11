//! A typed memory value at a fixed address in a process.
//!
//! Entry represents a single memory location found by a scan. It stores
//! the cached value, address, permissions, and owning process PID.
//! Entries can be re-read and written back through Lua.

const std = @import("std");
const zua = @import("zua");

const Permissions = @import("../region/perms.zig").Permissions;
const DataType = @import("../mem/types.zig").DataType;
const SimpleType = @import("../mem/types.zig").SimpleType;
const Memory = @import("../mem/memory.zig");
const Selector = @import("../mem/selector.zig").Selector;
const PinWatcher = @import("../mem/pin.zig").PinWatcher;
const PinKey = @import("../mem/pin.zig").PinKey;
const Display = @import("../display.zig");

pub const Scanner = @import("scanner.zig");

pub const Entry = @This();

const methods = .{
    .__gc = m_cleanup,
    .__tostring = m_display,
    .set = zua.Native.new(set, .{}, .{
        .description = "Writes a new value to this entry's address in the target process.",
        .args = &.{
            .{ .name = "value", .description = "Value to write." },
        },
    }),
    .get = zua.Native.new(get, .{}, .{
        .description = "Re-reads the entry's value from process memory and returns it.",
    }),
    .get_address = zua.Native.new(getAddress, .{}, .{
        .description = "Returns the memory address of this entry.",
    }),
    .get_pid = zua.Native.new(getPid, .{}, .{
        .description = "Returns the PID of the process this entry belongs to.",
    }),
    .get_perms = zua.Native.new(getPerms, .{}, .{
        .description = "Returns the memory permissions at this entry's address.",
    }),
    .pin = zua.Native.new(pin, .{}, .{
        .description = "Pins this entry so its value stays at the written amount.",
        .args = &.{
            .{ .name = "value", .description = "Optional value. Defaults to current cached value." },
        },
    }),
    .unpin = zua.Native.new(unpin, .{}, .{
        .description = "Unpins this entry. The value will no longer be kept at the pinned amount.",
    }),
};

pub const ZUA_META = zua.Meta.Object(Entry, methods, .{
    .name = "Entry",
    .description = "A typed memory value at a fixed address.",
});

/// A union of all supported types for cached entry values.
pub const Value = union(SimpleType) {
    u8: u8,
    u16: u16,
    u32: u32,
    u64: u64,
    i8: i8,
    i16: i16,
    i32: i32,
    i64: i64,
    f32: f32,
    f64: f64,
    str: []u8,

    pub fn from(comptime T: type, value: T) Value {
        if (comptime T == u8) return Value{ .u8 = value };
        if (comptime T == u16) return Value{ .u16 = value };
        if (comptime T == u32) return Value{ .u32 = value };
        if (comptime T == u64) return Value{ .u64 = value };
        if (comptime T == i8) return Value{ .i8 = value };
        if (comptime T == i16) return Value{ .i16 = value };
        if (comptime T == i32) return Value{ .i32 = value };
        if (comptime T == i64) return Value{ .i64 = value };
        if (comptime T == f32) return Value{ .f32 = value };
        if (comptime T == f64) return Value{ .f64 = value };
        @compileError("unsupported type");
    }

    pub fn display(self: Value, arena: std.mem.Allocator) ![]const u8 {
        var buf: [64]u8 = undefined;
        const s = switch (self) {
            .u8 => |v| try std.fmt.bufPrint(&buf, "{d}", .{v}),
            .u16 => |v| try std.fmt.bufPrint(&buf, "{d}", .{v}),
            .u32 => |v| try std.fmt.bufPrint(&buf, "{d}", .{v}),
            .u64 => |v| try std.fmt.bufPrint(&buf, "{d}", .{v}),
            .i8 => |v| try std.fmt.bufPrint(&buf, "{d}", .{v}),
            .i16 => |v| try std.fmt.bufPrint(&buf, "{d}", .{v}),
            .i32 => |v| try std.fmt.bufPrint(&buf, "{d}", .{v}),
            .i64 => |v| try std.fmt.bufPrint(&buf, "{d}", .{v}),
            .f32 => |v| try std.fmt.bufPrint(&buf, "{d}", .{v}),
            .f64 => |v| try std.fmt.bufPrint(&buf, "{d}", .{v}),
            .str => |v| try std.fmt.bufPrint(&buf, "\"{s}\"", .{v}),
        };
        return arena.dupe(u8, s);
    }

    pub fn deinit(self: *Value, heap: std.mem.Allocator) void {
        if (self.* == .str) {
            heap.free(self.str);
        }
    }
};

/// PID of the process this entry belongs to.
pid: std.posix.pid_t,
/// Memory permissions at this address.
perms: Permissions,
/// Virtual address of this entry in the target process.
address: usize,
/// Cached value at this address (typed according to the scan).
value: Value,


/// Re-reads the entry's value from process memory and returns it.
fn get(ctx: *zua.Context, self: *Entry) !zua.Decoder.Primitive {
    return switch (self.value) {
        .u8 => {
            const value = try readValue(u8, ctx, self);
            self.value = Value.from(u8, value);
            return .{ .integer = @intCast(value) };
        },
        .u16 => {
            const value = try readValue(u16, ctx, self);
            self.value = Value.from(u16, value);
            return .{ .integer = @intCast(value) };
        },
        .u32 => {
            const value = try readValue(u32, ctx, self);
            self.value = Value.from(u32, value);
            return .{ .integer = @intCast(value) };
        },
        .u64 => {
            const value = try readValue(u64, ctx, self);
            self.value = Value.from(u64, value);
            return blk: {
                if (std.math.cast(i64, value)) |int_value| {
                    break :blk .{ .integer = int_value };
                } else {
                    break :blk .{ .float = @floatFromInt(value) };
                }
            };
        },
        .i8 => {
            const value = try readValue(i8, ctx, self);
            self.value = Value.from(i8, value);
            return .{ .integer = @intCast(value) };
        },
        .i16 => {
            const value = try readValue(i16, ctx, self);
            self.value = Value.from(i16, value);
            return .{ .integer = @intCast(value) };
        },
        .i32 => {
            const value = try readValue(i32, ctx, self);
            self.value = Value.from(i32, value);
            return .{ .integer = @intCast(value) };
        },
        .i64 => {
            const value = try readValue(i64, ctx, self);
            self.value = Value.from(i64, value);
            return .{ .integer = value };
        },
        .f32 => {
            const value = try readValue(f32, ctx, self);
            self.value = Value.from(f32, value);
            return .{ .float = @floatCast(value) };
        },
        .f64 => {
            const value = try readValue(f64, ctx, self);
            self.value = Value.from(f64, value);
            return .{ .float = @floatCast(value) };
        },
        .str => {
            const buf = self.value.str;
            try Memory.readTyped(u8, ctx, self.pid, self.address, buf);
            return .{ .string = try ctx.arena().dupeZ(u8, buf) };
        },
    };
}

/// Writes a new value to the entry's address in the target process.
pub fn set(ctx: *zua.Context, self: *Entry, value: zua.Decoder.Primitive) !void {
    switch (self.value) {
        .u8 => try setTyped(u8, ctx, self, value),
        .u16 => try setTyped(u16, ctx, self, value),
        .u32 => try setTyped(u32, ctx, self, value),
        .u64 => try setTyped(u64, ctx, self, value),
        .i8 => try setTyped(i8, ctx, self, value),
        .i16 => try setTyped(i16, ctx, self, value),
        .i32 => try setTyped(i32, ctx, self, value),
        .i64 => try setTyped(i64, ctx, self, value),
        .f32 => try setTyped(f32, ctx, self, value),
        .f64 => try setTyped(f64, ctx, self, value),
        .str => {
            const val = try zua.Decoder.decodeValue(ctx, value, []const u8);
            if (val.len > self.value.str.len) {
                return ctx.failWithFmt("string too long (max {d} bytes)", .{self.value.str.len});
            }
            if (!self.perms.has(.write)) {
                return ctx.failWithFmt("entry at {x} is not writable", .{self.address});
            }
            try Memory.writeTyped(u8, ctx, self.pid, self.address, val);
            const buf = @constCast(self.value.str);
            @memcpy(buf[0..val.len], val);
            self.value = Value{ .str = buf[0..val.len] };
        },
    }
}

/// Tests whether the entry's current live value matches a selector.
fn readTypedCached(comptime T: type, ctx: *zua.Context, self: *Entry) !T {
    const value = try readValue(T, ctx, self);
    self.value = Value.from(T, value);
    return value;
}

pub fn matches(self: *Entry, ctx: *zua.Context, selector: Selector) !bool {
    return switch (self.value) {
        .u8 => |prev| try selector.matches(u8, ctx, try readTypedCached(u8, ctx, self), prev),
        .u16 => |prev| try selector.matches(u16, ctx, try readTypedCached(u16, ctx, self), prev),
        .u32 => |prev| try selector.matches(u32, ctx, try readTypedCached(u32, ctx, self), prev),
        .u64 => |prev| try selector.matches(u64, ctx, try readTypedCached(u64, ctx, self), prev),
        .i8 => |prev| try selector.matches(i8, ctx, try readTypedCached(i8, ctx, self), prev),
        .i16 => |prev| try selector.matches(i16, ctx, try readTypedCached(i16, ctx, self), prev),
        .i32 => |prev| try selector.matches(i32, ctx, try readTypedCached(i32, ctx, self), prev),
        .i64 => |prev| try selector.matches(i64, ctx, try readTypedCached(i64, ctx, self), prev),
        .f32 => |prev| try selector.matches(f32, ctx, try readTypedCached(f32, ctx, self), prev),
        .f64 => |prev| try selector.matches(f64, ctx, try readTypedCached(f64, ctx, self), prev),
        .str => |cached| {
            const live = try readStringValue(ctx, self);
            const result = try selector.matchesString(ctx, live, cached);
            @memcpy(self.value.str, live);
            return result;
        },
    };
}

/// Returns the memory address of this entry.
fn getAddress(self: *const Entry) usize {
    return self.address;
}

/// Returns the PID of the process this entry belongs to.
fn getPid(self: *const Entry) std.posix.pid_t {
    return self.pid;
}

/// Returns the memory permissions at this entry's address.
fn getPerms(self: *const Entry) Permissions {
    return self.perms;
}

/// Pins this entry.
pub fn pin(ctx: *zua.Context, self: *Entry, value: ?zua.Decoder.Primitive) !void {
    if (value) |v| try set(ctx, self, v);

    const watcher = try PinWatcher.getOrCreate(ctx);

    const cloned: Value = switch (self.value) {
        .str => |s| .{ .str = try ctx.heap().dupe(u8, s) },
        else => self.value,
    };

    const key = PinKey{ .address = self.address, .data_type = std.meta.activeTag(self.value) };
    try watcher.pin(key, .{
        .pin = .{ .address = self.address, .pid = self.pid, .value = cloned },
    });
}

/// Unpins this entry.
pub fn unpin(ctx: *zua.Context, self: *Entry) !void {
    const watcher = PinWatcher.get(ctx) orelse return ctx.fail("no entry pinned");
    const key = PinKey{ .address = self.address, .data_type = std.meta.activeTag(self.value) };
    try watcher.unpin(ctx, key);
}

fn m_cleanup(ctx: *zua.Context, self: *Entry) void {
    self.value.deinit(ctx.heap());
}

fn m_display(ctx: *zua.Context, self: *Entry) ![]const u8 {
    const addr_str = try std.fmt.allocPrint(ctx.arena(), "0x{x}", .{self.address});
    const pid_str = try std.fmt.allocPrint(ctx.arena(), "{d}", .{self.pid});
    const perms_str = try Permissions.display(ctx, self.perms);
    const val_str = try self.value.display(ctx.arena());
    return Display.formatTable(ctx, &.{
        .{ .key = "address", .val = addr_str },
        .{ .key = "pid", .val = pid_str },
        .{ .key = "perms", .val = perms_str },
        .{ .key = "value", .val = val_str },
    });
}


pub fn readValue(comptime T: type, ctx: *zua.Context, self: *const Entry) !T {
    var buffer: [1]T = undefined;
    try Memory.readTyped(T, ctx, self.pid, self.address, &buffer);
    return buffer[0];
}

pub fn readStringValue(ctx: *zua.Context, self: *const Entry) ![]u8 {
    const len = self.value.str.len;
    const buf = try ctx.arena().alloc(u8, len);
    try Memory.readTyped(u8, ctx, self.pid, self.address, buf);
    return buf;
}

fn setTyped(comptime T: type, ctx: *zua.Context, self: *Entry, value: zua.Decoder.Primitive) !void {
    const val: [1]T = .{try zua.Decoder.decodeValue(ctx, value, T)};
    if (!self.perms.has(.write)) {
        return ctx.failWithFmt("entry at {x} is not writable", .{self.address});
    }
    try Memory.writeTyped(T, ctx, self.pid, self.address, &val);
    self.value = Value.from(T, val[0]);
}

test {
    std.testing.refAllDecls(@This());
}
