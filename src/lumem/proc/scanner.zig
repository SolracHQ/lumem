//! Scanner performs the `/proc` traversal and builds process objects.
//! It is the implementation behind `lumem:scan()`.

pub const Scanner = @This();

const Process = @import("proc.zig");
const Filter = @import("filter.zig");

const zua = @import("zua");
const std = @import("std");

const proc_small_file_limit = 64 * 1024 + 1;

const StatusInfo = struct {
    parentPid: ?std.posix.pid_t = null,
    uid: ?std.posix.uid_t = null,
    gid: ?std.posix.gid_t = null,
};

/// Enumerates live `/proc` entries and returns the matched processes.
///
/// This is the low-level implementation used by `lumem:scan()`.
pub fn scan(ctx: *zua.Context, filter: *const Filter) ![]Process {
    var processList = std.ArrayList(Process).empty;
    errdefer {
        // Cleanup any processes that were successfully scanned before the error occurred.
        for (processList.items) |*proc| Process.cleanup(ctx, proc);
        // This is technically not necessary since the processes are allocated with the context's arena, but I want to train myself to always clean up resources properly.
        processList.deinit(ctx.arena());
    }

    var proc_dir = std.Io.Dir.cwd().openDir(ctx.state.io, "/proc", .{ .iterate = true }) catch |err| {
        return ctx.failWithFmtTyped([]Process, "Failed to open /proc: {s}", .{@errorName(err)});
    };
    defer proc_dir.close(ctx.state.io);

    var iter = proc_dir.iterateAssumeFirstIteration();
    while (try iter.next(ctx.state.io)) |entry| {
        if (entry.kind != .directory) continue;
        var dir = proc_dir.openDir(ctx.state.io, entry.name, .{}) catch |err| {
            // If we fail to open the process directory, we can skip this process since it's likely a transient process that has already exited.
            std.debug.print("Failed to open directory for PID {s}, skipping process: {s}:{s}\n", .{ entry.name, ctx.err.?, @errorName(err) });
            continue;
        };
        defer dir.close(ctx.state.io);
        const pid = parsePid(entry.name) orelse continue;
        const name = readName(ctx, dir) catch |err| {
            // If we fail to read the process name, we can skip this process since it's likely a transient process that has already exited.
            std.debug.print("Failed to read name for PID {d}, skipping process: {s}:{s}\n", .{ pid, ctx.err.?, @errorName(err) });
            continue;
        };
        const cmdLine = readCommandLine(ctx, dir) catch |err| {
            // If we fail to read the command line, we can skip this process since it's likely a transient process that has already exited.
            std.debug.print("Failed to read command line for PID {d}, skipping process: {s}:{s}\n", .{ pid, ctx.err.?, @errorName(err) });
            continue;
        };
        const status = parseStatus(ctx, dir) catch |err| {
            // If we fail to read the status, we can skip this process since it's likely a transient process that has already exited.
            std.debug.print("Failed to read status for PID {d}, skipping process: {s}:{s}\n", .{ pid, ctx.err.?, @errorName(err) });
            continue;
        };
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
            // If the process doesn't match the filter, we need to clean it up immediately since we're not returning it.
            Process.cleanup(ctx, &process);
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
    const raw = try readFile(ctx, dir, "comm");
    // Remove trailing newline if present.
    const trimmed = std.mem.trim(u8, raw, "\n\t\r");
    // Copy with owned allocator so the process owns its name and outlive the context
    return ctx.heap().dupe(u8, trimmed);
}

fn readCommandLine(ctx: *zua.Context, dir: std.Io.Dir) ![]const u8 {
    const raw = readFile(ctx, dir, "cmdline") catch |err| {
        return ctx.failWithFmtTyped([]const u8, "Failed to read process command line: {s}", .{@errorName(err)});
    };
    // The cmdline file is null-separated, so replace nulls with spaces.
    for (raw) |*byte| {
        if (byte.* == 0) byte.* = ' ';
    }
    const trimmed = std.mem.trim(u8, raw, "\n\t\r");
    // Copy with owned allocator so the process owns its command line and outlive the context
    return ctx.heap().dupe(u8, trimmed);
}

fn parseStatus(ctx: *zua.Context, dir: std.Io.Dir) !StatusInfo {
    const raw = try readFile(ctx, dir, "status");
    var status: StatusInfo = .{};

    var line_iter = std.mem.splitScalar(u8, raw, '\n');
    while (line_iter.next()) |line| {
        if (std.mem.startsWith(u8, line, "PPid:")) {
            const field = getStatusField(line, 5);
            if (field.len == 0) continue;
            status.parentPid = try parseStatusInt(std.posix.pid_t, ctx, "PPid", field);
        } else if (std.mem.startsWith(u8, line, "Uid:")) {
            const field = getStatusField(line, 4);
            if (field.len == 0) continue;
            status.uid = try parseStatusInt(std.posix.uid_t, ctx, "Uid", field);
        } else if (std.mem.startsWith(u8, line, "Gid:")) {
            const field = getStatusField(line, 4);
            if (field.len == 0) continue;
            status.gid = try parseStatusInt(std.posix.gid_t, ctx, "Gid", field);
        }
    }

    return status;
}

fn getStatusField(line: []const u8, prefix_len: usize) []const u8 {
    return std.mem.trim(u8, line[prefix_len..], " \t");
}

fn parseStatusInt(comptime T: type, ctx: *zua.Context, fieldName: []const u8, field: []const u8) !T {
    var tokens = std.mem.tokenizeAny(u8, field, " \t");
    const token = tokens.next() orelse
        return ctx.failWithFmtTyped(T, "Missing {s} value in status", .{fieldName});
    return std.fmt.parseInt(T, token, 10) catch
        return ctx.failWithFmtTyped(T, "Invalid {s} in status: {s}", .{ fieldName, field });
}

fn readFile(ctx: *zua.Context, dir: std.Io.Dir, name: []const u8) ![]u8 {
    var buffer: [proc_small_file_limit]u8 = undefined;
    const raw = dir.readFile(ctx.state.io, name, &buffer) catch |err| {
        return ctx.failWithFmtTyped([]u8, "Failed to read {s}: {s}", .{ name, @errorName(err) });
    };
    if (raw.len == buffer.len) {
        return ctx.failWithFmtTyped([]u8, "{s} is too large to read", .{name});
    }
    return ctx.arena().dupe(u8, raw);
}
