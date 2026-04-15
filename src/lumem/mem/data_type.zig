const std = @import("std");
const zua = @import("zua");

pub const TypeInfo = struct {
    ty: SimpleType,
    size: usize,
    alignment: usize,
};

pub const SimpleType = enum {
    U8,
    U16,
    U32,
    U64,
    I8,
    I16,
    I32,
    I64,
    F32,
    F64,

    pub fn typeInfo(self: SimpleType) TypeInfo {
        return switch (self) {
            .U8 => .{ .ty = self, .size = @sizeOf(u8), .alignment = @alignOf(u8) },
            .U16 => .{ .ty = self, .size = @sizeOf(u16), .alignment = @alignOf(u16) },
            .U32 => .{ .ty = self, .size = @sizeOf(u32), .alignment = @alignOf(u32) },
            .U64 => .{ .ty = self, .size = @sizeOf(u64), .alignment = @alignOf(u64) },
            .I8 => .{ .ty = self, .size = @sizeOf(i8), .alignment = @alignOf(i8) },
            .I16 => .{ .ty = self, .size = @sizeOf(i16), .alignment = @alignOf(i16) },
            .I32 => .{ .ty = self, .size = @sizeOf(i32), .alignment = @alignOf(i32) },
            .I64 => .{ .ty = self, .size = @sizeOf(i64), .alignment = @alignOf(i64) },
            .F32 => .{ .ty = self, .size = @sizeOf(f32), .alignment = @alignOf(f32) },
            .F64 => .{ .ty = self, .size = @sizeOf(f64), .alignment = @alignOf(f64) },
        };
    }
};

pub const AggregatedType = enum {
    number,
    integer,
    signed,
    unsigned,
    float,

    pub const NumberTypes: [10]SimpleType = .{ .U8, .U16, .U32, .U64, .I8, .I16, .I32, .I64, .F32, .F64 };

    pub const IntegerTypes: [8]SimpleType = .{ .U8, .U16, .U32, .U64, .I8, .I16, .I32, .I64 };

    pub const SignedTypes: [4]SimpleType = .{ .I8, .I16, .I32, .I64 };

    pub const UnsignedTypes: [4]SimpleType = .{ .U8, .U16, .U32, .U64 };

    pub const FloatTypes: [2]SimpleType = .{ .F32, .F64 };

    const Self = @This();

    pub fn types(self: AggregatedType) []const SimpleType {
        return switch (self) {
            .number => &Self.NumberTypes,
            .integer => &Self.IntegerTypes,
            .signed => &Self.SignedTypes,
            .unsigned => &Self.UnsignedTypes,
            .float => &Self.FloatTypes,
        };
    }
};

pub const DataType = union(enum) {
    Simple: SimpleType,
    Aggregated: AggregatedType,

    pub const ZUA_META = zua.Meta.Object(DataType, .{}).withDecode(decode);
};

fn decode(ctx: *zua.Context, value: zua.Decoder.Primitive) !DataType {
    return switch (value) {
        .string => |str| fromString(str, ctx),
        .userdata => |ud| zua.Object(DataType).from(ud).get().*,
        else => return ctx.failWithFmtTyped(DataType, "expected string or DataType userdata, got {s}", .{@tagName(value)}),
    };
}

fn fromString(str: []const u8, ctx: *zua.Context) !DataType {
    // Simple types
    if (std.mem.eql(u8, str, "u8")) return DataType{ .Simple = .U8 };
    if (std.mem.eql(u8, str, "u16")) return DataType{ .Simple = .U16 };
    if (std.mem.eql(u8, str, "u32")) return DataType{ .Simple = .U32 };
    if (std.mem.eql(u8, str, "u64")) return DataType{ .Simple = .U64 };
    if (std.mem.eql(u8, str, "i8")) return DataType{ .Simple = .I8 };
    if (std.mem.eql(u8, str, "i16")) return DataType{ .Simple = .I16 };
    if (std.mem.eql(u8, str, "i32")) return DataType{ .Simple = .I32 };
    if (std.mem.eql(u8, str, "i64")) return DataType{ .Simple = .I64 };
    if (std.mem.eql(u8, str, "f32")) return DataType{ .Simple = .F32 };
    if (std.mem.eql(u8, str, "f64")) return DataType{ .Simple = .F64 };
    // Aggregated types
    if (std.mem.eql(u8, str, "number")) return DataType{ .Aggregated = .number };
    if (std.mem.eql(u8, str, "integer")) return DataType{ .Aggregated = .integer };
    if (std.mem.eql(u8, str, "signed")) return DataType{ .Aggregated = .signed };
    if (std.mem.eql(u8, str, "int")) return DataType{ .Aggregated = .signed };
    if (std.mem.eql(u8, str, "unsigned")) return DataType{ .Aggregated = .unsigned };
    if (std.mem.eql(u8, str, "uint")) return DataType{ .Aggregated = .unsigned };
    if (std.mem.eql(u8, str, "float")) return DataType{ .Aggregated = .float };
    return ctx.failWithFmtTyped(DataType, "invalid data type: {s}", .{str});
}
