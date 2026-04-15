//! Scanner enumerates `/proc/<pid>/maps` and builds owned `Region` values.
//!
//! This module is used by `Process:regions()` to expose a process's memory
//! map to Lua consumers.

pub const Scanner = @This();

const std = @import("std");
const zua = @import("zua");
const Region = @import("region.zig");

const proc_maps_limit = 1024 * 1024;

/// Reads `/proc/<pid>/maps`, optionally filters by permissions, and returns
/// an owned slice of parsed `Region` values.
pub fn scan(ctx: *zua.Context, pid: std.posix.pid_t, filter: ?Region.Permissions) ![]Region {
    var proc_dir = std.Io.Dir.cwd().openDir(ctx.state.io, "/proc", .{ .iterate = true }) catch |err| {
        return ctx.failWithFmtTyped([]Region, "Failed to open /proc: {s}", .{@errorName(err)});
    };
    defer proc_dir.close(ctx.state.io);

    var pid_path_buffer: [32]u8 = undefined;
    const pid_path = try std.fmt.bufPrint(&pid_path_buffer, "{d}", .{pid});
    var pid_dir = try proc_dir.openDir(ctx.state.io, pid_path, .{});
    defer pid_dir.close(ctx.state.io);

    var maps_buffer: [proc_maps_limit]u8 = undefined;
    const maps_data = try pid_dir.readFile(ctx.state.io, "maps", &maps_buffer);
    if (maps_data.len == maps_buffer.len) return error.StreamTooLong;

    var regions = std.ArrayList(Region).empty;
    errdefer {
        for (regions.items) |region| ctx.arena().free(region.pathname);
        regions.deinit(ctx.arena());
    }

    var lines = std.mem.splitScalar(u8, maps_data, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0) continue;

        const region = try parseLine(ctx.heap(), trimmed, pid);
        if (filter == null or region.perms.hasAll(filter.?)) {
            try regions.append(ctx.arena(), region);
        } else {
            ctx.heap().free(region.pathname);
        }
    }

    return regions.items;
}

/// Parses a single `/proc/<pid>/maps` line into a `Region` value.
fn parseLine(allocator: std.mem.Allocator, line: []const u8, pid: std.posix.pid_t) !Region {
    var cursor: usize = 0;
    const address_field = nextField(line, &cursor) orelse return error.InvalidLine;
    const perms_field = nextField(line, &cursor) orelse return error.InvalidLine;
    const offset_field = nextField(line, &cursor) orelse return error.InvalidLine;
    _ = nextField(line, &cursor) orelse return error.InvalidLine;
    const inode_field = nextField(line, &cursor) orelse return error.InvalidLine;
    while (cursor < line.len and isWhitespace(line[cursor])) cursor += 1;
    const pathname_field = line[cursor..];

    const range = std.mem.indexOfScalar(u8, address_field, '-') orelse return error.InvalidLine;
    const start = try std.fmt.parseInt(usize, address_field[0..range], 16);
    const end = try std.fmt.parseInt(usize, address_field[range + 1 ..], 16);
    if (start > end) return error.InvalidLine;

    const perms = try parsePermissions(perms_field);
    const offset = try std.fmt.parseInt(usize, offset_field, 16);
    const inode = try std.fmt.parseInt(u64, inode_field, 10);
    const pathname = try allocator.dupe(u8, pathname_field);

    return Region{
        .pid = pid,
        .start = start,
        .end = end,
        .offset = offset,
        .inode = inode,
        .perms = perms,
        .pathname = pathname,
    };
}

/// Parses a 4-character permissions field from `/proc/<pid>/maps`.
fn parsePermissions(field: []const u8) !Region.Permissions {
    if (field.len != 4) return error.InvalidPermissions;
    var perms: Region.Permissions = .{ .bits = 0 };
    if (field[0] == 'r') {
        perms.bits |= @intFromEnum(Region.Permissions.Permission.read);
    } else if (field[0] != '-') return error.InvalidPermissions;
    if (field[1] == 'w') {
        perms.bits |= @intFromEnum(Region.Permissions.Permission.write);
    } else if (field[1] != '-') return error.InvalidPermissions;
    if (field[2] == 'x') {
        perms.bits |= @intFromEnum(Region.Permissions.Permission.execute);
    } else if (field[2] != '-') return error.InvalidPermissions;
    if (field[3] == 's') {
        perms.bits |= @intFromEnum(Region.Permissions.Permission.shared);
    } else if (field[3] == 'p') {
        perms.bits |= @intFromEnum(Region.Permissions.Permission.private);
    } else return error.InvalidPermissions;
    return perms;
}

/// Reads the next whitespace-delimited field from a `/proc/<pid>/maps` line.
fn nextField(line: []const u8, cursor: *usize) ?[]const u8 {
    while (cursor.* < line.len and isWhitespace(line[cursor.*])) cursor.* += 1;
    if (cursor.* == line.len) return null;
    const start = cursor.*;
    while (cursor.* < line.len and !isWhitespace(line[cursor.*])) cursor.* += 1;
    return line[start..cursor.*];
}

fn isWhitespace(char: u8) bool {
    return char == ' ' or char == '\t';
}

pub const Error = error{ InvalidLine, InvalidPermissions, StreamTooLong };
