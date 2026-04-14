//! Memory region metadata parsed from `/proc/<pid>/maps`.
//! Memory region metadata parsed from `/proc/<pid>/maps`.
//!
//! Region objects are exposed to Lua with getters for address, size,
//! permissions, and mapped pathname.
const std = @import("std");
const zua = @import("zua");
const FilterModule = @import("filter.zig");

pub const Region = @This();

pub const Permissions = FilterModule.Permissions;

pub const ZUA_META = zua.Meta.Object(Region, .{
    .__gc = cleanup,
    .__tostring = display,
    .getStart = getStart,
    .getEnd = getEnd,
    .getSize = getSize,
    .getOffset = getOffset,
    .getInode = getInode,
    .getPerms = getPerms,
    .getPathname = getPathname,
});

/// Starting address of the memory region.
start: usize,

/// Ending address of the memory region.
end: usize,

/// Offset into the mapped file.
offset: usize,

/// Inode of the mapped object.
inode: u64,

/// Region permissions parsed from `/proc/<pid>/maps`.
perms: FilterModule.Permissions,

/// Pathname of the mapped object, or empty when the region is anonymous.
pathname: []const u8,

/// Frees the region pathname buffer when Lua garbage-collects the object.
pub fn cleanup(ctx: *zua.Context, self: *Region) void {
    ctx.state.allocator.free(self.pathname);
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
fn getPerms(self: *const Region) FilterModule.Permissions {
    return self.perms;
}

/// Returns the pathname of the region, or an empty string for anonymous regions.
fn getPathname(self: *const Region) []const u8 {
    return self.pathname;
}

fn display(ctx: *zua.Context, self: *Region) ![]const u8 {
    const pathname = if (self.pathname.len == 0) "(anonymous)" else self.pathname;
    const perms_str = try FilterModule.Permissions.display(ctx, self.perms);
    const fmt = "region(0x{x}-0x{x}, perms={s}, path={s})";
    return std.fmt.allocPrint(ctx.allocator(), fmt, .{ self.start, self.end, perms_str, pathname }) catch ctx.failTyped([]const u8, "Out of memory");
}
