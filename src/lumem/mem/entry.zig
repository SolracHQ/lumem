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

pub const Scanner = @import("scanner.zig");

pub const Entry = @This();

const methods = .{
    .set = zua.Native.new(set, .{}, .{
        .description = "Writes a new value to this entry's address in the target process.",
        .args = &.{
            .{ .name = "value", .description = "Value to write." },
        },
    }),
    .get = zua.Native.new(get, .{}, .{
        .description = "Re-reads the entry's value from process memory and returns it.",
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
    }
}

/// Tests whether the entry's current live value matches a selector.
pub fn matches(self: *const Entry, ctx: *zua.Context, selector: Selector) !bool {
    return switch (self.value) {
        .u8 => |value| try selector.matches(u8, ctx, try readValue(u8, ctx, self), value),
        .u16 => |value| try selector.matches(u16, ctx, try readValue(u16, ctx, self), value),
        .u32 => |value| try selector.matches(u32, ctx, try readValue(u32, ctx, self), value),
        .u64 => |value| try selector.matches(u64, ctx, try readValue(u64, ctx, self), value),
        .i8 => |value| try selector.matches(i8, ctx, try readValue(i8, ctx, self), value),
        .i16 => |value| try selector.matches(i16, ctx, try readValue(i16, ctx, self), value),
        .i32 => |value| try selector.matches(i32, ctx, try readValue(i32, ctx, self), value),
        .i64 => |value| try selector.matches(i64, ctx, try readValue(i64, ctx, self), value),
        .f32 => |value| try selector.matches(f32, ctx, try readValue(f32, ctx, self), value),
        .f64 => |value| try selector.matches(f64, ctx, try readValue(f64, ctx, self), value),
    };
}


fn readValue(comptime T: type, ctx: *zua.Context, self: *const Entry) !T {
    var buffer: [1]T = undefined;
    try Memory.readTyped(T, ctx, self.pid, self.address, &buffer);
    return buffer[0];
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
