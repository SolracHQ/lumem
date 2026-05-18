//! Process filter parameters used by `lumem:scan()`.
//!
//! Accepted as a string (shorthand for { name = s }) or a table with
//! optional pid, uid, name, and cmdLine fields.

const std = @import("std");
const zua = @import("zua");
const Process = @import("process.zig");

pub const Filter = @This();

/// Filter by exact process ID.
pid: ?std.posix.pid_t = null,
/// Filter by exact user ID.
uid: ?std.posix.uid_t = null,
/// Filter by substring match within the process name.
name: ?[]const u8 = null,
/// Filter by substring match within the command line.
cmdLine: ?[]const u8 = null,

pub const ZUA_SHAPE = zua.Shape.Table(Filter, .{}, .{
    .name = "Filter",
})
    .withDecode(decode)
    .withDocs(filterDocs);

/// Returns true when the process matches all non-null filter fields.
pub fn matches(self: *const Filter, proc: *const Process) bool {
    if (self.pid) |pid| {
        if (proc.pid.value != pid) return false;
    }
    if (self.uid) |uid| {
        if (proc.uid.value != uid) return false;
    }
    if (self.name) |name| {
        if (std.mem.find(u8, proc.name.value, name) == null) return false;
    }
    if (self.cmdLine) |cmdLine| {
        if (std.mem.find(u8, proc.cmdLine.value, cmdLine) == null) return false;
    }
    return true;
}

fn decode(_: *zua.Context, prim: zua.Mapper.Primitive) !?Filter {
    return switch (prim) {
        .string => |s| Filter{ .name = s },
        else => null,
    };
}

fn filterDocs(self: *zua.Docs.Generator) !void {
    var alias = zua.Docs.Entry.Alias{
        .name = try self.arena.allocator().dupe(u8, "Filter"),
        .description = try self.arena.allocator().dupe(u8, "Process filter criteria. Accepts a table with optional fields, or a string (shorthand for { name = s })."),
        .values = .empty,
    };
    try alias.values.append(self.arena.allocator(), .{
        .type = try self.arena.allocator().dupe(u8, "string"),
        .description = "Shorthand for { name = s }.",
    });
    try alias.values.append(self.arena.allocator(), .{
        .type = try zua.Docs.Internals.Helpers.structToAliasShape(self, Filter),
        .description = "Table of filter criteria.",
    });
    try self.aliases.append(self.arena.allocator(), alias);
}

test {
    std.testing.refAllDecls(@This());
}
