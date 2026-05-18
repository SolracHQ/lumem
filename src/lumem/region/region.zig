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
    .get_size = zua.Shape.Fn(getSize, .{
        .description = "Returns the size of this region in bytes.",
    }),
    .scan = zua.Shape.Fn(scan, .{
        .description = "Scans this region for memory values matching the data type and selector.",
        .args = &.{
            .{ .name = "dataType", .description = "Data type to scan for." },
            .{ .name = "selector", .description = "Comparison predicate table." },
        },
    }),
};

pub const ZUA_SHAPE = zua.Shape.Object(Region, methods, .{
    .name = "Region",
    .description = "A mapped memory region with address bounds, permissions, and pathname.",
});

/// Process ID that the region belongs to.
pid: zua.Shape.Modifier.Value(std.posix.pid_t, .{ .description = "Process ID." }),
/// Starting address of the memory region.
start: zua.Shape.Modifier.Value(usize, .{ .description = "Start address." }),
/// Ending address of the memory region.
end: zua.Shape.Modifier.Value(usize, .{ .description = "End address." }),
/// Offset into the mapped file.
offset: zua.Shape.Modifier.Value(usize, .{ .description = "File offset." }),
/// Inode of the mapped object.
inode: zua.Shape.Modifier.Value(u64, .{ .description = "Mapped inode, or 0 if anonymous." }),
/// Region permission flags.
perms: zua.Shape.Modifier.Value(Permissions, .{ .description = "Permission flags." }),
/// Pathname of the mapped object, or empty when the region is anonymous.
pathname: zua.Shape.Modifier.Value([]const u8, .{ .description = "Mapped file pathname." }),

pub fn cleanup(ctx: *zua.Context, self: *Region) void {
    ctx.heap().free(self.pathname.value);
}

fn getSize(self: *const Region) usize {
    return self.end.value - self.start.value;
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
    const start_str = try std.fmt.allocPrint(ctx.arena(), "0x{x}", .{self.start.value});
    const end_str = try std.fmt.allocPrint(ctx.arena(), "0x{x}", .{self.end.value});
    const size_str = try std.fmt.allocPrint(ctx.arena(), "{d}", .{self.end.value - self.start.value});
    const perms_str = try Permissions.display(ctx, self.perms.value);
    const path_str = if (self.pathname.value.len == 0)
        "nil"
    else
        try Display.quoted(ctx.arena(), self.pathname.value);
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
