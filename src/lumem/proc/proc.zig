//! Process represents a live system process exposed to Lua.
//! It is the value returned by `lumem:scan()` and supports read-only
//! inspection of process metadata.

pub const Process = @This();

const std = @import("std");
const zua = @import("zua");

pub const Scanner = @import("scanner.zig");
pub const Filter = @import("filter.zig");
pub const List = @import("list.zig");
const Region = @import("../region/region.zig");
const RegionList = @import("../region/list.zig");
const RegionScanner = @import("../region/scanner.zig");

/// Zua metadata for `Process` objects.
///
/// Fields are exposed through Lua methods such as `:getParentPid()` and
/// `:getCmdLine()`.
pub const ZUA_META = zua.Meta.Object(Process, .{
    .__gc = cleanup,
    .__tostring = display,
    .getParentPid = getParentPid,
    .getUid = getUid,
    .getGid = getGid,
    .getCmdLine = getCmdLine,
    .regions = regions,
});

/// Parent process ID, if available.
parentPid: ?std.posix.pid_t,

/// Process ID.
pid: std.posix.pid_t,

/// User ID that owns the process, if available.
uid: ?std.posix.uid_t,

/// Group ID that owns the process, if available.
gid: ?std.posix.gid_t,

/// Process name as reported by `/proc/<pid>/comm`.
name: []const u8,

/// Full process command line, with null separators replaced by spaces.
cmdLine: []const u8,

/// Frees the process metadata buffer when Lua garbage-collects the object.
pub fn cleanup(ctx: *zua.Context, self: *Process) void {
    ctx.heap().free(self.name);
    ctx.heap().free(self.cmdLine);
}

/// Returns the process parent PID, or `nil` when unavailable.
pub fn getParentPid(self: *const Process) ?std.posix.pid_t {
    return self.parentPid;
}

/// Returns the user ID of the process owner, or `nil` when unavailable.
pub fn getUid(self: *const Process) ?std.posix.uid_t {
    return self.uid;
}

/// Returns the group ID of the process owner, or `nil` when unavailable.
pub fn getGid(self: *const Process) ?std.posix.gid_t {
    return self.gid;
}

/// Returns the process command line as a single string.
pub fn getCmdLine(self: *const Process) []const u8 {
    return self.cmdLine;
}

pub fn regions(ctx: *zua.Context, self: *const Process, filter: ?Region.Permissions) !RegionList.List {
    const _regions = try RegionScanner.scan(ctx, self.pid, filter orelse try Region.Permissions.fromString(ctx, "rw--"));
    return try RegionList.init(ctx, _regions);
}

fn display(ctx: *zua.Context, self: *Process) ![]const u8 {
    const fmt = "Process {{ pid: {x}, name: {s} }}";
    const args = .{ self.pid, self.name };
    return std.fmt.allocPrint(ctx.arena(), fmt, args) catch ctx.failTyped([]const u8, "Out of memory");
}
