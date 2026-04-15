//! Permission definitions and decoding helpers for process memory regions.
//!
//! These types are used when examining region permissions from `/proc/<pid>/maps`
//! and when the Lua API accepts permission filters.

/// A bitfield representing region permissions.
///
/// Supports decoding from Lua values and helpers for matching required flags.
pub const Permissions = @This();

const std = @import("std");
const zua = @import("zua");
const Decoder = zua.Mapper.Decoder;

/// Region memory permission bits parsed from `/proc/<pid>/maps`.
pub const Permission = enum(u8) {
    read = 1 << 0,
    write = 1 << 1,
    execute = 1 << 2,
    shared = 1 << 3,
    private = 1 << 4,
};

bits: u8,

pub const ZUA_META = zua.Meta.Table(Permissions, .{
    .__tostring = display,
}).withDecode(decode);

/// Decodes a `Permissions` value from a Lua string, integer, or table.
/// - String format: "rwxp" (read/write/execute + shared/private)
/// - Integer format: bitfield of `Permission` values
/// - Table format: array of permission names, e.g. `{ "read", "write" }`
fn decode(ctx: *zua.Context, value: Decoder.Primitive) !Permissions {
    return switch (value) {
        .integer => |n| blk: {
            const bits = std.math.cast(u8, n) orelse
                return ctx.failTyped(Permissions, "permission integer out of range");
            break :blk .{ .bits = bits };
        },
        .string => |s| parseString(ctx, s),
        .table => |t| parseTable(ctx, t),
        else => ctx.failTyped(Permissions, "expected permission string, integer, or table"),
    };
}

/// Formats permissions as a `/proc/<pid>/maps`-style 4-character string.
pub fn display(ctx: *zua.Context, self: Permissions) ![]const u8 {
    var buf: [4]u8 = [_]u8{ '-', '-', '-', '-' };
    if (self.has(.read)) buf[0] = 'r';
    if (self.has(.write)) buf[1] = 'w';
    if (self.has(.execute)) buf[2] = 'x';
    if (self.has(.shared)) buf[3] = 's';
    if (self.has(.private)) buf[3] = 'p';
    return ctx.arena().dupe(u8, &buf);
}

/// Returns `true` when the given permission bit is present.
pub fn has(self: Permissions, perm: Permission) bool {
    return (self.bits & @intFromEnum(perm)) != 0;
}

/// Returns `true` when all required permission bits are present.
pub fn hasAll(self: Permissions, required: Permissions) bool {
    return (self.bits & required.bits) == required.bits;
}

/// Parses a 4-character permission string such as "rw-p".
pub fn fromString(ctx: *zua.Context, s: []const u8) !Permissions {
    return parseString(ctx, s);
}

fn parseString(ctx: *zua.Context, s: []const u8) !Permissions {
    if (s.len != 4) {
        return ctx.failTyped(Permissions, "permission string must be 4 characters");
    }

    var bits: u8 = 0;
    if (s[0] == 'r') bits |= @intFromEnum(Permission.read);

    if (s[1] == 'w') bits |= @intFromEnum(Permission.write);

    if (s[2] == 'x') bits |= @intFromEnum(Permission.execute);

    if (s[3] == 's') {
        bits |= @intFromEnum(Permission.shared);
    } else if (s[3] == 'p') {
        bits |= @intFromEnum(Permission.private);
    }

    return .{ .bits = bits };
}

fn parseTable(ctx: *zua.Context, table: zua.Table) !Permissions {
    var perms: Permissions = .{ .bits = 0 };
    var index: usize = 1;
    var seen = false;

    while (table.has(index)) {
        const name = try table.get(ctx, index, []const u8);
        const perm = try parsePermissionName(ctx, name);
        perms.bits |= @intFromEnum(perm);
        seen = true;
        index += 1;
    }

    if (!seen) {
        return ctx.failTyped(Permissions, "permission table must contain at least one entry");
    }

    return perms;
}

fn parsePermissionName(ctx: *zua.Context, name: []const u8) !Permission {
    if (std.mem.eql(u8, name, "read")) return Permission.read;
    if (std.mem.eql(u8, name, "write")) return Permission.write;
    if (std.mem.eql(u8, name, "execute")) return Permission.execute;
    if (std.mem.eql(u8, name, "shared")) return Permission.shared;
    if (std.mem.eql(u8, name, "private")) return Permission.private;
    if (std.mem.eql(u8, name, "r")) return Permission.read;
    if (std.mem.eql(u8, name, "w")) return Permission.write;
    if (std.mem.eql(u8, name, "x")) return Permission.execute;
    if (std.mem.eql(u8, name, "s")) return Permission.shared;
    if (std.mem.eql(u8, name, "p")) return Permission.private;
    return ctx.failTyped(Permission, "unknown permission name");
}
