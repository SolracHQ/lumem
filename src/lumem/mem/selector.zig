//! Selection predicates for filtering memory scan results.
//!
//! A Selector is a tagged union that describes which memory values to
//! include in a scan result.

const std = @import("std");
const zua = @import("zua");

pub const Selector = union(enum) {
    pub const ZUA_META = zua.Meta.Table(Selector, .{
        .__gc = deinit,
    }, .{
        .name = "Selector",
        .description = "A comparison predicate for filtering memory scan results.",
    }).withDecode(decode);

    eq: zua.Decoder.Primitive,
    gt: zua.Decoder.Primitive,
    lt: zua.Decoder.Primitive,
    ge: zua.Decoder.Primitive,
    le: zua.Decoder.Primitive,
    ne: zua.Decoder.Primitive,
    range: []zua.Decoder.Primitive,
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

    pub fn matches(self: *const Selector, comptime T: type, ctx: *zua.Context, value: T, prev_value: ?T) !bool {
        return switch (self.*) {
            .eq => |v| value == try zua.Decoder.decodeValue(ctx, v, T),
            .gt => |v| value > try zua.Decoder.decodeValue(ctx, v, T),
            .lt => |v| value < try zua.Decoder.decodeValue(ctx, v, T),
            .ge => |v| value >= try zua.Decoder.decodeValue(ctx, v, T),
            .le => |v| value <= try zua.Decoder.decodeValue(ctx, v, T),
            .ne => |v| value != try zua.Decoder.decodeValue(ctx, v, T),
            .range => |range| value >= try zua.Decoder.decodeValue(ctx, range[0], T) and value <= try zua.Decoder.decodeValue(ctx, range[1], T),
            .change => |change_type| switch (change_type) {
                .increase => if (prev_value) |prev| value > prev else true,
                .decrease => if (prev_value) |prev| value < prev else true,
                .none => if (prev_value) |prev| value == prev else true,
                .any => true,
            },
            .custom => |f| try f.call(ctx, .{ value, prev_value }, bool),
        };
    }

    fn decode(ctx: *zua.Context, primitive: zua.Mapper.Decoder.Primitive) !?Selector {
        switch (primitive) {
            .table => |tbl| {
                if (tbl.has("custom")) {
                    return .{ .custom = (try tbl.get(ctx, "custom", zua.Function)).takeOwnership() };
                }
                if (tbl.has("range")) {
                    const range = try tbl.get(ctx, "range", []zua.Decoder.Primitive);
                    if (range.len != 2) {
                        return ctx.failTyped(?Selector, "range selector requires exactly 2 values");
                    }
                    return .{ .range = range };
                }
                return null;
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

test {
    std.testing.refAllDecls(@This());
}
