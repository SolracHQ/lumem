//! Selection predicates for filtering memory scan results.
//!
//! A Selector is a tagged union that describes which memory values to
//! include in a scan result. Accepted from Lua as a table with a single
//! key, a plain number (shorthand for { eq = x }), a plain string (shorthand
//! for { eq = s }), or a function (shorthand for { custom = f }).
//!
//! For string scans the available keys are eq, ne, contains, prefix, change,
//! and custom. Numeric selectors like gt error when used with string data.

const std = @import("std");
const zua = @import("zua");

const SimpleType = @import("types.zig").SimpleType;
const DataType = @import("types.zig").DataType;

pub const Selector = union(enum) {
    pub const ZUA_META = zua.Meta.Table(Selector, .{
        .__gc = deinit,
    }, .{
        .name = "Selector",
    }).withDecode(decode).withDocs(selectorDocs);

    eq: zua.Decoder.Primitive,
    gt: zua.Decoder.Primitive,
    lt: zua.Decoder.Primitive,
    ge: zua.Decoder.Primitive,
    le: zua.Decoder.Primitive,
    ne: zua.Decoder.Primitive,
    range: []zua.Decoder.Primitive,
    contains: zua.Decoder.Primitive,
    prefix: zua.Decoder.Primitive,
    change: enum {
        pub const ZUA_META = zua.Meta.strEnum(@This(), .{}, .{
            .name = "ChangeType",
            .description = "Describes how a value changed since the last scan.",
        });
        increase,
        decrease,
        none,
        any,
    },
    custom: zua.Function,
    type: DataType,

    pub const StringError = error{ NoTarget, NotSupported };

    pub fn stringTargetLen(self: *const Selector) StringError!usize {
        const prim = switch (self.*) {
            .eq => |v| v,
            .ne => |v| v,
            .contains => |v| v,
            .prefix => |v| v,
            .custom => return error.NoTarget,
            .change => return error.NoTarget,
            else => return error.NotSupported,
        };
        return switch (prim) {
            .string => |s| s.len,
            .table => error.NoTarget,
            else => error.NotSupported,
        };
    }

    pub fn resolveTargetLen(self: *const Selector, ctx: *zua.Context) !usize {
        const prim = switch (self.*) {
            .eq => |v| v,
            .ne => |v| v,
            .contains => |v| v,
            .prefix => |v| v,
            .custom => return 80,
            .change => return 0,
            else => return ctx.failWithFmtTyped(usize, "selector not supported for string scans", .{}),
        };
        return switch (prim) {
            .string => |s| s.len,
            .table => (try zua.Decoder.decodeValue(ctx, prim, []const u8)).len,
            else => return ctx.failWithFmtTyped(usize, "selector not supported for string scans", .{}),
        };
    }

    pub fn matchesString(self: *const Selector, ctx: *zua.Context, value: []const u8, prev_value: ?[]const u8) !bool {
        return switch (self.*) {
            .eq => |v| std.mem.eql(u8, value, try zua.Decoder.decodeValue(ctx, v, []const u8)),
            .ne => |v| !std.mem.eql(u8, value, try zua.Decoder.decodeValue(ctx, v, []const u8)),
            .contains => |v| std.mem.find(u8, value, try zua.Decoder.decodeValue(ctx, v, []const u8)) != null,
            .prefix => |v| std.mem.startsWith(u8, value, try zua.Decoder.decodeValue(ctx, v, []const u8)),
            .change => |change_type| switch (change_type) {
                .none => if (prev_value) |prev| std.mem.eql(u8, value, prev) else true,
                .any => if (prev_value) |prev| !std.mem.eql(u8, value, prev) else true,
                .increase, .decrease => return ctx.failWithFmtTyped(bool, "increase/decrease not supported for string values", .{}),
            },
            .custom => |f| try f.call(ctx, .{ value, prev_value }, bool),
            .type => true,
            .range, .gt, .ge, .lt, .le => return ctx.failWithFmtTyped(bool, "selector not supported for string values", .{}),
        };
    }

    pub fn matches(self: *const Selector, comptime T: type, ctx: *zua.Context, value: T, prev_value: ?T) !bool {
        return switch (self.*) {
            .eq => |v| value == try zua.Decoder.decodeValue(ctx, v, T),
            .gt => |v| value > try zua.Decoder.decodeValue(ctx, v, T),
            .lt => |v| value < try zua.Decoder.decodeValue(ctx, v, T),
            .ge => |v| value >= try zua.Decoder.decodeValue(ctx, v, T),
            .le => |v| value <= try zua.Decoder.decodeValue(ctx, v, T),
            .ne => |v| value != try zua.Decoder.decodeValue(ctx, v, T),
            .range => |range| value >= try zua.Decoder.decodeValue(ctx, range[0], T) and value <= try zua.Decoder.decodeValue(ctx, range[1], T),
            .contains, .prefix => return ctx.failWithFmtTyped(bool, "contains/prefix only supported for string scans", .{}),
            .change => |change_type| switch (change_type) {
                .increase => if (prev_value) |prev| value > prev else true,
                .decrease => if (prev_value) |prev| value < prev else true,
                .none => if (prev_value) |prev| value == prev else true,
                .any => if (prev_value) |prev| value != prev else true,
            },
            .custom => |f| try f.call(ctx, .{ value, prev_value }, bool),
            .type => true,
        };
    }

    fn decode(ctx: *zua.Context, primitive: zua.Mapper.Decoder.Primitive) !?Selector {
        switch (primitive) {
            .table => |tbl| {
                if (tbl.has("custom")) {
                    return .{ .custom = (try tbl.get(ctx, "custom", zua.Function)).takeOwnership() };
                }
                inline for (.{ "eq", "ne", "contains", "prefix" }) |key| {
                    if (tbl.has(key)) {
                        const prim = try tbl.get(ctx, key, zua.Decoder.Primitive);
                        if (prim == .table) {
                            const bytes = try zua.Decoder.decodeValue(ctx, prim, []const u8);
                            try tbl.set(ctx, key, bytes);
                        }
                    }
                }
                return null;
            },
            .integer, .float => {
                return .{ .eq = primitive };
            },
            .string => {
                return .{ .eq = primitive };
            },
            .function => |f| {
                return .{ .custom = f.takeOwnership() };
            },
            else => return ctx.failTyped(?Selector, "expected table for Selector"),
        }
    }

    fn deinit(self: *Selector) void {
        if (self.* == .custom) {
            self.custom.release();
        }
    }
};

fn selectorDocs(self: *zua.Docs) !void {
    const ChangeType = comptime blk: {
        for (@typeInfo(Selector).@"union".fields) |f| {
            if (std.mem.eql(u8, f.name, "change")) break :blk f.type;
        }
        @compileError("change field not found");
    };
    try self.add(ChangeType);

    var alias = zua.Docs.Alias{
        .name = try self.arena.allocator().dupe(u8, "Selector"),
        .description = try self.arena.allocator().dupe(u8, "A comparison predicate for filtering memory scan results."),
        .values = .empty,
    };
    try alias.values.append(self.arena.allocator(), .{
        .type = try self.arena.allocator().dupe(u8, "number"),
        .description = "Shorthand for { eq = x }.",
    });
    try alias.values.append(self.arena.allocator(), .{
        .type = try self.arena.allocator().dupe(u8, "string"),
        .description = "Shorthand for { eq = s }.",
    });
    try alias.values.append(self.arena.allocator(), .{
        .type = try self.arena.allocator().dupe(u8, "function"),
        .description = "Shorthand for { custom = f }.",
    });
    try alias.values.append(self.arena.allocator(), .{
        .type = try self.arena.allocator().dupe(u8, "{ eq: any }"),
        .description = "Equal to the given value.",
    });
    try alias.values.append(self.arena.allocator(), .{
        .type = try self.arena.allocator().dupe(u8, "{ gt: any }"),
        .description = "Greater than the given value.",
    });
    try alias.values.append(self.arena.allocator(), .{
        .type = try self.arena.allocator().dupe(u8, "{ lt: any }"),
        .description = "Less than the given value.",
    });
    try alias.values.append(self.arena.allocator(), .{
        .type = try self.arena.allocator().dupe(u8, "{ ge: any }"),
        .description = "Greater than or equal to the given value.",
    });
    try alias.values.append(self.arena.allocator(), .{
        .type = try self.arena.allocator().dupe(u8, "{ le: any }"),
        .description = "Less than or equal to the given value.",
    });
    try alias.values.append(self.arena.allocator(), .{
        .type = try self.arena.allocator().dupe(u8, "{ ne: any }"),
        .description = "Not equal to the given value.",
    });
    try alias.values.append(self.arena.allocator(), .{
        .type = try self.arena.allocator().dupe(u8, "{ range: any[] }"),
        .description = "Inclusive range as { lo, hi }.",
    });
    try alias.values.append(self.arena.allocator(), .{
        .type = try self.arena.allocator().dupe(u8, "{ contains: any }"),
        .description = "Substring match (strings only).",
    });
    try alias.values.append(self.arena.allocator(), .{
        .type = try self.arena.allocator().dupe(u8, "{ prefix: any }"),
        .description = "Prefix match (strings only).",
    });
    try alias.values.append(self.arena.allocator(), .{
        .type = try self.arena.allocator().dupe(u8, "{ change: ChangeType }"),
        .description = "Change type: increase, decrease, none, any.",
    });
    try alias.values.append(self.arena.allocator(), .{
        .type = try self.arena.allocator().dupe(u8, "{ custom: function }"),
        .description = "Custom Lua function(value, prev_value) returning bool.",
    });
    try self.aliases.append(self.arena.allocator(), alias);
}

test {
    std.testing.refAllDecls(@This());
}
