pub const Entry = @This();

const Permissions = @import("../region/perms.zig").Permissions;
const DataType = @import("../mem/data_type.zig").DataType;
const SimpleType = @import("../mem/data_type.zig").SimpleType;
const Ops = @import("../mem/ops.zig");

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

fn set(ctx: *zua.Context, self: *Entry, value: zua.Decoder.Primitive) !void {
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

fn get(self: *Entry) zua.Decoder.Primitive {
    return switch (self.value) {
        .U8 => |v| .{ .integer = @intCast(v) },
        .U16 => |v| .{ .integer = @intCast(v) },
        .U32 => |v| .{ .integer = @intCast(v) },
        .U64 => |v| blk: {
            if (std.math.cast(i64, v)) |value| {
                break :blk .{ .integer = value };
            } else {
                break :blk .{ .float = @floatFromInt(v) };
            }
        },
        .I8 => |v| .{ .integer = @intCast(v) },
        .I16 => |v| .{ .integer = @intCast(v) },
        .I32 => |v| .{ .integer = @intCast(v) },
        .I64 => |v| .{ .integer = v },
        .F32 => |v| .{ .float = @floatCast(v) },
        .F64 => |v| .{ .float = @floatCast(v) },
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
