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
const Display = @import("../display.zig");

pub const Process = @This();

/// Parent process ID, or nil.
parentPid: zua.Shape.Modifier.Value(?std.posix.pid_t, .{ .description = "Parent process ID, or nil." }),
/// Process ID.
pid: zua.Shape.Modifier.Value(std.posix.pid_t, .{ .description = "Process ID." }),
/// User ID that owns the process, or nil.
uid: zua.Shape.Modifier.Value(?std.posix.uid_t, .{ .description = "User ID that owns the process, or nil." }),
/// Group ID of the process, or nil.
gid: zua.Shape.Modifier.Value(?std.posix.gid_t, .{ .description = "Group ID of the process, or nil." }),
/// Process name.
name: zua.Shape.Modifier.Value([]const u8, .{ .description = "Process name." }),
/// Full process command line.
cmdLine: zua.Shape.Modifier.Value([]const u8, .{ .description = "Full process command line." }),

const methods = .{
    .__gc = cleanup,
    .__tostring = display,
    .regions = zua.Shape.Fn(regions, .{
        .description = "Returns the memory regions for this process, optionally filtered by permissions.",
        .args = &.{
            .{ .name = "filter", .description = "Optional permission filter string (\"rwxp\") or table of names." },
        },
    }),
    .scan = zua.Shape.Fn(scan, .{
        .description = "Scans the process memory for values matching the data type and selector.",
        .args = &.{
            .{ .name = "dataType", .description = "Data type to scan for (\"u8\", \"i32\", \"f64\", etc.)." },
            .{ .name = "selector", .description = "Comparison predicate table." },
            .{ .name = "filter", .description = "Optional permission filter." },
        },
    }),
};

pub const ZUA_SHAPE = zua.Shape.Object(Process, methods, .{
    .name = "Process",
    .description = "A system process with metadata and memory scanning capabilities.",
});

pub fn cleanup(ctx: *zua.Context, self: *Process) void {
    ctx.heap().free(self.name.value);
    ctx.heap().free(self.cmdLine.value);
}

/// Returns the memory regions for this process, optionally filtered by permissions.
pub fn regions(ctx: *zua.Context, self: *const Process, filter: ?Region.Permissions) !RegionList {
    const _regions = try RegionScanner.scan(ctx, self.pid.value, filter orelse try Region.Permissions.fromString(ctx, "rw--"));
    return try RegionList.init(ctx, _regions);
}

/// Scans the process memory for values matching the data type and selector.
pub fn scan(ctx: *zua.Context, self: *const Process, dataType: DataType, selector: Selector, filter: ?Region.Permissions) !EntryList {
    const region_filter = filter orelse try Region.Permissions.fromString(ctx, "rw--");
    const _regions = try RegionScanner.scan(ctx, self.pid.value, region_filter);
    defer for (_regions) |*region| {
        Region.cleanup(ctx, region);
    };

    var entries = std.ArrayList(Entry).empty;
    errdefer entries.deinit(ctx.arena());

    for (_regions) |*region| {
        const region_entries = try MemScanner.scanRegion(ctx, region, dataType, selector);
        try entries.appendSlice(ctx.arena(), region_entries);
    }

    return try EntryList.init(ctx, entries.items);
}

/// Formats the process for Lua tostring().
fn display(ctx: *zua.Context, self: *Process) ![]const u8 {
    const pid_str = try std.fmt.allocPrint(ctx.arena(), "{d}", .{self.pid.value});
    const name_str = try Display.quoted(ctx.arena(), self.name.value);
    const cmd_str = try Display.quoted(ctx.arena(), Display.truncate(self.cmdLine.value, 80));
    const ppid_str = if (self.parentPid.value) |pp|
        try std.fmt.allocPrint(ctx.arena(), "{d}", .{pp})
    else
        "nil";
    const uid_str = if (self.uid.value) |u|
        try std.fmt.allocPrint(ctx.arena(), "{d}", .{u})
    else
        "nil";
    const gid_str = if (self.gid.value) |g|
        try std.fmt.allocPrint(ctx.arena(), "{d}", .{g})
    else
        "nil";
    return Display.formatTable(ctx, &.{
        .{ .key = "pid", .val = pid_str },
        .{ .key = "name", .val = name_str },
        .{ .key = "cmd_line", .val = cmd_str },
        .{ .key = "parent_pid", .val = ppid_str },
        .{ .key = "uid", .val = uid_str },
        .{ .key = "gid", .val = gid_str },
    });
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
            .parentPid = .new(status.parentPid),
            .pid = .new(pid),
            .uid = .new(status.uid),
            .gid = .new(status.gid),
            .name = .new(name),
            .cmdLine = .new(cmdLine),
        };

        if (filter.matches(&process)) {
            try processList.append(ctx.arena(), process);
        } else {
            cleanup(ctx, &process);
        }
    }
    return processList.toOwnedSlice(ctx.arena());
}

/// Returns a Process for the current process. No root needed.
/// Useful when loaded as a shared library via require("lumem").
pub fn getSelf(ctx: *zua.Context) !Process {
    var proc_dir = std.Io.Dir.cwd().openDir(ctx.state.io, "/proc", .{}) catch |err| {
        return ctx.failWithFmtTyped(Process, "Failed to open /proc: {s}", .{@errorName(err)});
    };
    defer proc_dir.close(ctx.state.io);
    var self_dir = try proc_dir.openDir(ctx.state.io, "self", .{});
    defer self_dir.close(ctx.state.io);
    const pid = std.os.linux.getpid();
    const name = try readName(ctx, self_dir);
    const cmdLine = try readCmdLine(ctx, self_dir);
    const status = try parseStatus(ctx, self_dir);
    return Process{
        .parentPid = .new(status.parentPid),
        .pid = .new(pid),
        .uid = .new(status.uid),
        .gid = .new(status.gid),
        .name = .new(name),
        .cmdLine = .new(cmdLine),
    };
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
