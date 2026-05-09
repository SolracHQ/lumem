//! Memory region metadata with address bounds, permissions, and pathname.
//!
//! Region objects are exposed to Lua with getters for address, size,
//! permissions, and mapped pathname.

const std = @import("std");
const zua = @import("zua");

const DataType = @import("../mem/types.zig").DataType;
const Selector = @import("../mem/selector.zig").Selector;
const EntryList = @import("../mem/list.zig").List;
const Scanner = @import("../mem/scanner.zig");
const Display = @import("../display.zig");

pub const Permissions = @import("perms.zig");

pub const Region = @This();

const methods = .{
    .__gc = cleanup,
    .__tostring = display,
    .get_start = zua.Native.new(getStart, .{}, .{
        .description = "Returns the start address of this region.",
    }),
    .get_end = zua.Native.new(getEnd, .{}, .{
        .description = "Returns the end address of this region.",
    }),
    .get_size = zua.Native.new(getSize, .{}, .{
        .description = "Returns the size of this region in bytes.",
    }),
    .get_offset = zua.Native.new(getOffset, .{}, .{
        .description = "Returns the file offset of this region.",
    }),
    .get_inode = zua.Native.new(getInode, .{}, .{
        .description = "Returns the inode of the mapped file, or 0 if anonymous.",
    }),
    .get_perms = zua.Native.new(getPerms, .{}, .{
        .description = "Returns the permission flags of this region.",
    }),
    .get_pathname = zua.Native.new(getPathname, .{}, .{
        .description = "Returns the mapped file pathname, or empty string if anonymous.",
    }),
    .scan = zua.Native.new(scan, .{}, .{
        .description = "Scans this region for memory values matching the data type and selector.",
        .args = &.{
            .{ .name = "dataType", .description = "Data type to scan for." },
            .{ .name = "selector", .description = "Comparison predicate table." },
        },
    }),
};

pub const ZUA_META = zua.Meta.Object(Region, methods, .{
    .name = "Region",
    .description = "A mapped memory region with address bounds, permissions, and pathname.",
});


/// Process ID that the region belongs to.
pid: std.posix.pid_t,
/// Starting address of the memory region.
start: usize,
/// Ending address of the memory region.
end: usize,
/// Offset into the mapped file.
offset: usize,
/// Inode of the mapped object.
inode: u64,
/// Region permission flags.
perms: Permissions,
/// Pathname of the mapped object, or empty when the region is anonymous.
pathname: []const u8,


/// Frees the region pathname buffer when Lua garbage-collects the object.
pub fn cleanup(ctx: *zua.Context, self: *Region) void {
    ctx.heap().free(self.pathname);
}


/// Returns the starting address of the region.
fn getStart(self: *const Region) usize {
    return self.start;
}

/// Returns the size of the region.
fn getSize(self: *const Region) usize {
    return self.end - self.start;
}

/// Returns the ending address of the region.
fn getEnd(self: *const Region) usize {
    return self.end;
}

/// Returns the offset into the mapped file.
fn getOffset(self: *const Region) usize {
    return self.offset;
}

/// Returns the inode of the mapped object.
fn getInode(self: *const Region) u64 {
    return self.inode;
}

/// Returns the region permissions.
fn getPerms(self: *const Region) Permissions {
    return self.perms;
}

/// Returns the pathname of the region, or an empty string for anonymous regions.
fn getPathname(self: *const Region) []const u8 {
    return self.pathname;
}

/// Scans the region for values of the specified type that match the selector.
///
/// Lua usage:
/// ```lua
/// local entries = region:scan("u32", {eq = 0x12345678})
/// ```
fn scan(ctx: *zua.Context, self: *Region, dataType: DataType, selector: Selector) !EntryList {
    const entries = try Scanner.scanRegion(ctx, self, dataType, selector);
    return try EntryList.init(ctx, entries);
}

/// Formats the region for Lua tostring().
fn display(ctx: *zua.Context, self: *Region) ![]const u8 {
    const start_str = try std.fmt.allocPrint(ctx.arena(), "0x{x}", .{self.start});
    const end_str = try std.fmt.allocPrint(ctx.arena(), "0x{x}", .{self.end});
    const size_str = try std.fmt.allocPrint(ctx.arena(), "{d}", .{self.end - self.start});
    const perms_str = try Permissions.display(ctx, self.perms);
    const path_str = if (self.pathname.len == 0)
        "nil"
    else
        try Display.quoted(ctx.arena(), self.pathname);
    return Display.formatTable(ctx, &.{
        .{ .key = "start", .val = start_str },
        .{ .key = "end", .val = end_str },
        .{ .key = "size", .val = size_str },
        .{ .key = "perms", .val = perms_str },
        .{ .key = "pathname", .val = path_str },
    });
}

test {
    std.testing.refAllDecls(@This());
}
