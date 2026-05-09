//! Process represents a live system process exposed to Lua.
//! It is the value returned by `lumem:scan()` and supports read-only
//! inspection of process metadata.

const std = @import("std");
const zua = @import("zua");

pub const Filter = @import("filter.zig");
pub const List = @import("list.zig");
const Region = @import("../region/region.zig");
const RegionList = @import("../region/list.zig").List;
const RegionScanner = @import("../region/scanner.zig");
const MemScanner = @import("../mem/scanner.zig");
const Entry = @import("../mem/entry.zig").Entry;
const EntryList = @import("../mem/list.zig").List;
const DataType = @import("../mem/types.zig").DataType;
const Selector = @import("../mem/selector.zig").Selector;

pub const Process = @This();

/// Parent process ID, if available.
parentPid: ?std.posix.pid_t,
/// Process ID.
pid: std.posix.pid_t,
/// User ID that owns the process, if available.
uid: ?std.posix.uid_t,
/// Group ID that owns the process, if available.
gid: ?std.posix.gid_t,
/// Process name.
name: []const u8,
/// Full process command line.
cmdLine: []const u8,

pub const ZUA_META = zua.Meta.Object(Process, .{
    .__gc = cleanup,
    .__tostring = display,
    .getParentPid = getParentPid,
    .getUid = getUid,
    .getGid = getGid,
    .getCmdLine = getCmdLine,
    .regions = regions,
    .scan = scan,
}, .{
    .name = "Process",
    .description = "A system process with metadata and memory scanning capabilities.",
});


/// Frees the process metadata buffer when Lua garbage-collects the object.
pub fn cleanup(ctx: *zua.Context, self: *Process) void {
    ctx.heap().free(self.name);
    ctx.heap().free(self.cmdLine);
}


/// Returns the process parent PID, or nil when unavailable.
pub fn getParentPid(self: *const Process) ?std.posix.pid_t {
    return self.parentPid;
}

/// Returns the user ID of the process owner, or nil when unavailable.
pub fn getUid(self: *const Process) ?std.posix.uid_t {
    return self.uid;
}

/// Returns the group ID of the process owner, or nil when unavailable.
pub fn getGid(self: *const Process) ?std.posix.gid_t {
    return self.gid;
}

/// Returns the process command line as a single string.
pub fn getCmdLine(self: *const Process) []const u8 {
    return self.cmdLine;
}

pub fn regions(ctx: *zua.Context, self: *const Process, filter: ?Region.Permissions) !RegionList {
    const _regions = try RegionScanner.scan(ctx, self.pid, filter orelse try Region.Permissions.fromString(ctx, "rw--"));
    return try RegionList.init(ctx, _regions);
}

pub fn scan(ctx: *zua.Context, self: *const Process, dataType: DataType, selector: Selector, filter: ?Region.Permissions) !EntryList {
    const region_filter = filter orelse try Region.Permissions.fromString(ctx, "rw--");
    const _regions = try RegionScanner.scan(ctx, self.pid, region_filter);
    defer for (_regions) |*region| {
        Region.cleanup(ctx, region);
    };

    var entries = std.ArrayList(Entry).empty;
    errdefer entries.deinit(ctx.arena());

    for (_regions) |region| {
        const region_entries = try MemScanner.scanRegion(ctx, region, dataType, selector);
        try entries.appendSlice(ctx.arena(), region_entries);
    }

    return try EntryList.init(ctx, entries.items);
}

fn display(ctx: *zua.Context, self: *Process) ![]const u8 {
    const fmt = "Process {{ pid: {d}, name: {s} }}";
    const args = .{ self.pid, self.name };
    return std.fmt.allocPrint(ctx.arena(), fmt, args) catch ctx.failTyped([]const u8, "Out of memory");
}


const proc_small_file_limit = 64 * 1024 + 1;

const StatusInfo = struct {
    parentPid: ?std.posix.pid_t = null,
    uid: ?std.posix.uid_t = null,
    gid: ?std.posix.gid_t = null,
};

/// Enumerates all running processes and returns those matching the filter.
pub fn scanAll(ctx: *zua.Context, filter: *const Filter) ![]Process {
    var processList = std.ArrayList(Process).empty;
    errdefer {
        for (processList.items) |*p| cleanup(ctx, p);
        processList.deinit(ctx.arena());
    }

    var proc_dir = std.Io.Dir.cwd().openDir(ctx.state.io, "/proc", .{ .iterate = true }) catch |err| {
        return ctx.failWithFmtTyped([]Process, "Failed to open /proc: {s}", .{@errorName(err)});
    };
    defer proc_dir.close(ctx.state.io);

    var iter = proc_dir.iterateAssumeFirstIteration();
    while (try iter.next(ctx.state.io)) |entry| {
        if (entry.kind != .directory) continue;
        var dir = proc_dir.openDir(ctx.state.io, entry.name, .{}) catch {
            continue;
        };
        defer dir.close(ctx.state.io);
        const pid = parsePid(entry.name) orelse continue;
        const name = readName(ctx, dir) catch continue;
        const cmdLine = readCmdLine(ctx, dir) catch continue;
        const status = parseStatus(ctx, dir) catch continue;
        var process = Process{
            .parentPid = status.parentPid,
            .pid = pid,
            .uid = status.uid,
            .gid = status.gid,
            .name = name,
            .cmdLine = cmdLine,
        };

        if (filter.matches(&process)) {
            try processList.append(ctx.arena(), process);
        } else {
            cleanup(ctx, &process);
        }
    }
    return processList.toOwnedSlice(ctx.arena());
}

fn parsePid(text: []const u8) ?std.posix.pid_t {
    if (text.len == 0) return null;
    for (text) |char| {
        if (!std.ascii.isDigit(char)) return null;
    }
    return std.fmt.parseInt(std.posix.pid_t, text, 10) catch null;
}

fn readName(ctx: *zua.Context, dir: std.Io.Dir) ![]const u8 {
    const raw = try readSmallFile(ctx, dir, "comm");
    const trimmed = std.mem.trim(u8, raw, "\n\t\r");
    return ctx.heap().dupe(u8, trimmed);
}

fn readCmdLine(ctx: *zua.Context, dir: std.Io.Dir) ![]const u8 {
    const raw = try readSmallFile(ctx, dir, "cmdline");
    for (raw) |*byte| {
        if (byte.* == 0) byte.* = ' ';
    }
    const trimmed = std.mem.trim(u8, raw, "\n\t\r");
    return ctx.heap().dupe(u8, trimmed);
}

fn parseStatus(ctx: *zua.Context, dir: std.Io.Dir) !StatusInfo {
    const raw = try readSmallFile(ctx, dir, "status");
    var status: StatusInfo = .{};
    var lines = std.mem.splitScalar(u8, raw, '\n');
    while (lines.next()) |line| {
        if (std.mem.startsWith(u8, line, "PPid:")) {
            const field = std.mem.trim(u8, line[5..], " \t");
            if (field.len > 0) status.parentPid = std.fmt.parseInt(std.posix.pid_t, field, 10) catch null;
        } else if (std.mem.startsWith(u8, line, "Uid:")) {
            const field = std.mem.trim(u8, line[4..], " \t");
            var tokens = std.mem.tokenizeAny(u8, field, " \t");
            if (tokens.next()) |tok| status.uid = std.fmt.parseInt(std.posix.uid_t, tok, 10) catch null;
        } else if (std.mem.startsWith(u8, line, "Gid:")) {
            const field = std.mem.trim(u8, line[4..], " \t");
            var tokens = std.mem.tokenizeAny(u8, field, " \t");
            if (tokens.next()) |tok| status.gid = std.fmt.parseInt(std.posix.gid_t, tok, 10) catch null;
        }
    }
    return status;
}

fn readSmallFile(ctx: *zua.Context, dir: std.Io.Dir, name: []const u8) ![]u8 {
    var buffer: [proc_small_file_limit]u8 = undefined;
    const raw = try dir.readFile(ctx.state.io, name, &buffer);
    if (raw.len == buffer.len) {
        return ctx.failWithFmtTyped([]u8, "{s} is too large to read", .{name});
    }
    return ctx.arena().dupe(u8, raw);
}

test {
    std.testing.refAllDecls(@This());
}
