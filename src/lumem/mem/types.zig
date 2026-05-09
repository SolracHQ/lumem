//! Scalar type definitions and data type selectors for memory operations.
//!
//! Defines the 10 fixed-size scalar types (SimpleType), type families
//! like "signed" or "number" (AggregatedType), and the DataType union
//! that bridges both into a single Lua-facing type.

const std = @import("std");
const zua = @import("zua");

pub const TypeInfo = struct {
    ty: SimpleType,
    size: usize,
    alignment: usize,
};

/// The 10 fixed-size scalar types supported for memory reads and writes.
pub const SimpleType = enum {
    u8,
    u16,
    u32,
    u64,
    i8,
    i16,
    i32,
    i64,
    f32,
    f64,

    pub fn typeInfo(self: SimpleType) TypeInfo {
        return switch (self) {
            .u8 => .{ .ty = self, .size = @sizeOf(u8), .alignment = @alignOf(u8) },
            .u16 => .{ .ty = self, .size = @sizeOf(u16), .alignment = @alignOf(u16) },
            .u32 => .{ .ty = self, .size = @sizeOf(u32), .alignment = @alignOf(u32) },
            .u64 => .{ .ty = self, .size = @sizeOf(u64), .alignment = @alignOf(u64) },
            .i8 => .{ .ty = self, .size = @sizeOf(i8), .alignment = @alignOf(i8) },
            .i16 => .{ .ty = self, .size = @sizeOf(i16), .alignment = @alignOf(i16) },
            .i32 => .{ .ty = self, .size = @sizeOf(i32), .alignment = @alignOf(i32) },
            .i64 => .{ .ty = self, .size = @sizeOf(i64), .alignment = @alignOf(i64) },
            .f32 => .{ .ty = self, .size = @sizeOf(f32), .alignment = @alignOf(f32) },
            .f64 => .{ .ty = self, .size = @sizeOf(f64), .alignment = @alignOf(f64) },
        };
    }
};

pub const AggregatedType = enum {
    number,
    integer,
    signed,
    unsigned,
    int,
    uint,
    float,

    pub const NumberTypes: [10]SimpleType = .{ .u8, .u16, .u32, .u64, .i8, .i16, .i32, .i64, .f32, .f64 };
    pub const IntegerTypes: [8]SimpleType = .{ .u8, .u16, .u32, .u64, .i8, .i16, .i32, .i64 };
    pub const SignedTypes: [4]SimpleType = .{ .i8, .i16, .i32, .i64 };
    pub const UnsignedTypes: [4]SimpleType = .{ .u8, .u16, .u32, .u64 };
    pub const FloatTypes: [2]SimpleType = .{ .f32, .f64 };

    pub fn types(self: AggregatedType) []const SimpleType {
        return switch (self) {
            .number => &NumberTypes,
            .integer => &IntegerTypes,
            .signed, .int => &SignedTypes,
            .unsigned, .uint => &UnsignedTypes,
            .float => &FloatTypes,
        };
    }
};

pub const DataType = union(enum) {
    Simple: SimpleType,
    Aggregated: AggregatedType,

    pub const ZUA_META = zua.Meta.Table(DataType, .{}, .{
        .name = "DataType",
        .description = "A scalar or family type for memory operations.",
    }).withDecode(decode).withDocs(dataTypeDocs);
};

fn decode(ctx: *zua.Context, value: zua.Decoder.Primitive) !?DataType {
    return switch (value) {
        .string => |str| {
            if (fromName(str)) |dt| return dt;
            return ctx.failWithFmtTyped(?DataType, "invalid data type: {s}", .{str});
        },
        .userdata => null,
        else => return ctx.failWithFmtTyped(?DataType, "expected string or DataType userdata, got {s}", .{@tagName(value)}),
    };
}

fn fromName(name: []const u8) ?DataType {
    if (std.meta.stringToEnum(SimpleType, name)) |st| return .{ .Simple = st };
    if (std.meta.stringToEnum(AggregatedType, name)) |tf| return .{ .Aggregated = tf };
    return null;
}

fn dataTypeDocs(self: *zua.Docs) !void {
    var alias = zua.Docs.Alias{
        .name = try self.arena.allocator().dupe(u8, "DataType"),
        .description = try self.arena.allocator().dupe(u8, "A scalar or family type for memory operations."),
        .values = .empty,
    };
    for ([_]struct { type: []const u8, desc: []const u8 }{
        .{ .type = "'u8'", .desc = "8-bit unsigned integer" },
        .{ .type = "'u16'", .desc = "16-bit unsigned integer" },
        .{ .type = "'u32'", .desc = "32-bit unsigned integer" },
        .{ .type = "'u64'", .desc = "64-bit unsigned integer" },
        .{ .type = "'i8'", .desc = "8-bit signed integer" },
        .{ .type = "'i16'", .desc = "16-bit signed integer" },
        .{ .type = "'i32'", .desc = "32-bit signed integer" },
        .{ .type = "'i64'", .desc = "64-bit signed integer" },
        .{ .type = "'f32'", .desc = "32-bit float" },
        .{ .type = "'f64'", .desc = "64-bit float" },
        .{ .type = "'number'", .desc = "any numeric type" },
        .{ .type = "'integer'", .desc = "any integer type" },
        .{ .type = "'signed'", .desc = "any signed integer type" },
        .{ .type = "'int'", .desc = "any signed integer type" },
        .{ .type = "'unsigned'", .desc = "any unsigned integer type" },
        .{ .type = "'uint'", .desc = "any unsigned integer type" },
        .{ .type = "'float'", .desc = "any float type" },
    }) |entry| {
        try alias.values.append(self.arena.allocator(), .{
            .type = entry.type,
            .description = entry.desc,
        });
    }
    try self.aliases.append(self.arena.allocator(), alias);
}

fn fromString(str: []const u8, ctx: *zua.Context) !DataType {
    if (std.mem.eql(u8, str, "u8")) return DataType{ .Simple = .u8 };
    if (std.mem.eql(u8, str, "u16")) return DataType{ .Simple = .u16 };
    if (std.mem.eql(u8, str, "u32")) return DataType{ .Simple = .u32 };
    if (std.mem.eql(u8, str, "u64")) return DataType{ .Simple = .u64 };
    if (std.mem.eql(u8, str, "i8")) return DataType{ .Simple = .i8 };
    if (std.mem.eql(u8, str, "i16")) return DataType{ .Simple = .i16 };
    if (std.mem.eql(u8, str, "i32")) return DataType{ .Simple = .i32 };
    if (std.mem.eql(u8, str, "i64")) return DataType{ .Simple = .i64 };
    if (std.mem.eql(u8, str, "f32")) return DataType{ .Simple = .f32 };
    if (std.mem.eql(u8, str, "f64")) return DataType{ .Simple = .f64 };
    if (std.mem.eql(u8, str, "number")) return DataType{ .Aggregated = .number };
    if (std.mem.eql(u8, str, "integer")) return DataType{ .Aggregated = .integer };
    if (std.mem.eql(u8, str, "signed")) return DataType{ .Aggregated = .signed };
    if (std.mem.eql(u8, str, "int")) return DataType{ .Aggregated = .signed };
    if (std.mem.eql(u8, str, "unsigned")) return DataType{ .Aggregated = .unsigned };
    if (std.mem.eql(u8, str, "uint")) return DataType{ .Aggregated = .unsigned };
    if (std.mem.eql(u8, str, "float")) return DataType{ .Aggregated = .float };
    return ctx.failWithFmtTyped(DataType, "invalid data type: {s}", .{str});
}

test {
    std.testing.refAllDecls(@This());
}
