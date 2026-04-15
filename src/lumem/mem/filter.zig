const std = @import("std");
const zua = @import("zua");

pub const Selector = union(enum) {
    eq: zua.Decoder.Primitive,
    gt: zua.Decoder.Primitive,
    lt: zua.Decoder.Primitive,
    ge: zua.Decoder.Primitive,
    le: zua.Decoder.Primitive,
    ne: zua.Decoder.Primitive,
    range: struct { zua.Decoder.Primitive, zua.Decoder.Primitive },
    change: enum {
        pub const ZUA_META = zua.Meta.strEnum(@This(), .{});
        increase,
        decrease,
        none,
        any,
    },

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
        };
    }
};
