//! Process filter parameters used by `lumem:scan()`.
//!
//! The filter is a plain Lua table with optional fields that narrow the
//! process enumeration results.

const std = @import("std");
const Process = @import("proc.zig");

pub const Filter = @This();

/// Filter by exact process ID.
pid: ?std.posix.pid_t = null,

/// Filter by exact user ID.
uid: ?std.posix.uid_t = null,

/// Filter by substring match within the process name.
name: ?[]const u8 = null,

/// Filter by substring match within the command line.
cmdLine: ?[]const u8 = null,

/// Returns `true` when the process matches all configured filter fields.
pub fn matches(self: *const Filter, proc: *const Process) bool {
    if (self.pid) |pid| {
        if (proc.pid != pid) {
            return false;
        }
    }
    if (self.uid) |uid| {
        if (proc.uid != uid) {
            return false;
        }
    }
    if (self.name) |name| {
        if (std.mem.find(u8, proc.name, name) == null) {
            return false;
        }
    }
    if (self.cmdLine) |cmdLine| {
        if (std.mem.find(u8, proc.cmdLine, cmdLine) == null) {
            return false;
        }
    }
    return true;
}
