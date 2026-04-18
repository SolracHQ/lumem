pub const Entry = @This();

const Permissions = @import("../region/perms.zig").Permissions;
const DataType = @import("../mem/data_type.zig").DataType;
const SimpleType = @import("../mem/data_type.zig").SimpleType;
const Ops = @import("../mem/ops.zig");
const Selector = @import("../mem/filter.zig").Selector;

const zua = @import("zua");
const std = @import("std");

pub const Scanner = @import("scanner.zig");

pub const ZUA_META = zua.Meta.Object(Entry, .{
    .set = set,
    .get = get,
});

pub const Value = union(SimpleType) {
    U8: u8,
    U16: u16,
    U32: u32,
    U64: u64,
    I8: i8,
    I16: i16,
    I32: i32,
    I64: i64,
    F32: f32,
    F64: f64,

    pub fn from(comptime T: type, value: T) Value {
        if (comptime T == u8) return Value{ .U8 = value };
        if (comptime T == u16) return Value{ .U16 = value };
        if (comptime T == u32) return Value{ .U32 = value };
        if (comptime T == u64) return Value{ .U64 = value };
        if (comptime T == i8) return Value{ .I8 = value };
        if (comptime T == i16) return Value{ .I16 = value };
        if (comptime T == i32) return Value{ .I32 = value };
        if (comptime T == i64) return Value{ .I64 = value };
        if (comptime T == f32) return Value{ .F32 = value };
        if (comptime T == f64) return Value{ .F64 = value };
        @compileError("unsupported type");
    }
};

pid: std.posix.pid_t,
perms: Permissions,
address: usize,
value: Value,

pub fn set(ctx: *zua.Context, self: *Entry, value: zua.Decoder.Primitive) !void {
    switch (self.value) {
        .U8 => try setTyped(u8, ctx, self, value),
        .U16 => try setTyped(u16, ctx, self, value),
        .U32 => try setTyped(u32, ctx, self, value),
        .U64 => try setTyped(u64, ctx, self, value),
        .I8 => try setTyped(i8, ctx, self, value),
        .I16 => try setTyped(i16, ctx, self, value),
        .I32 => try setTyped(i32, ctx, self, value),
        .I64 => try setTyped(i64, ctx, self, value),
        .F32 => try setTyped(f32, ctx, self, value),
        .F64 => try setTyped(f64, ctx, self, value),
    }
}

fn readValue(comptime T: type, ctx: *zua.Context, self: *const Entry) !T {
    var buffer: [1]T = undefined;
    try Ops.readTyped(T, ctx, self.pid, self.address, &buffer);
    return buffer[0];
}

pub fn matches(self: *const Entry, ctx: *zua.Context, selector: Selector) !bool {
    return switch (self.value) {
        .U8 => |value| try selector.matches(u8, ctx, try readValue(u8, ctx, self), value),
        .U16 => |value| try selector.matches(u16, ctx, try readValue(u16, ctx, self), value),
        .U32 => |value| try selector.matches(u32, ctx, try readValue(u32, ctx, self), value),
        .U64 => |value| try selector.matches(u64, ctx, try readValue(u64, ctx, self), value),
        .I8 => |value| try selector.matches(i8, ctx, try readValue(i8, ctx, self), value),
        .I16 => |value| try selector.matches(i16, ctx, try readValue(i16, ctx, self), value),
        .I32 => |value| try selector.matches(i32, ctx, try readValue(i32, ctx, self), value),
        .I64 => |value| try selector.matches(i64, ctx, try readValue(i64, ctx, self), value),
        .F32 => |value| try selector.matches(f32, ctx, try readValue(f32, ctx, self), value),
        .F64 => |value| try selector.matches(f64, ctx, try readValue(f64, ctx, self), value),
    };
}

fn get(ctx: *zua.Context, self: *Entry) !zua.Decoder.Primitive {
    return switch (self.value) {
        .U8 => {
            const value = try readValue(u8, ctx, self);
            self.value = Value.from(u8, value);
            return .{ .integer = @intCast(value) };
        },
        .U16 => {
            const value = try readValue(u16, ctx, self);
            self.value = Value.from(u16, value);
            return .{ .integer = @intCast(value) };
        },
        .U32 => {
            const value = try readValue(u32, ctx, self);
            self.value = Value.from(u32, value);
            return .{ .integer = @intCast(value) };
        },
        .U64 => {
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
        .I8 => {
            const value = try readValue(i8, ctx, self);
            self.value = Value.from(i8, value);
            return .{ .integer = @intCast(value) };
        },
        .I16 => {
            const value = try readValue(i16, ctx, self);
            self.value = Value.from(i16, value);
            return .{ .integer = @intCast(value) };
        },
        .I32 => {
            const value = try readValue(i32, ctx, self);
            self.value = Value.from(i32, value);
            return .{ .integer = @intCast(value) };
        },
        .I64 => {
            const value = try readValue(i64, ctx, self);
            self.value = Value.from(i64, value);
            return .{ .integer = value };
        },
        .F32 => {
            const value = try readValue(f32, ctx, self);
            self.value = Value.from(f32, value);
            return .{ .float = @floatCast(value) };
        },
        .F64 => {
            const value = try readValue(f64, ctx, self);
            self.value = Value.from(f64, value);
            return .{ .float = @floatCast(value) };
        },
    };
}

fn setTyped(comptime T: type, ctx: *zua.Context, self: *Entry, value: zua.Decoder.Primitive) !void {
    const val: [1]T = .{try zua.Decoder.decodeValue(ctx, value, T)};
    if (!self.perms.has(.write)) {
        return ctx.failWithFmt("entry at {x} is not writable", .{self.address});
    }
    try Ops.writeTyped(T, ctx, self.pid, self.address, &val);
    self.value = Value.from(T, val[0]);
}
