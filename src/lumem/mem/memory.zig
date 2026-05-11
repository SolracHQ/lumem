//! Reads and writes memory in a target process.
//!
//! Takes a type, pid, address, and buffer. Returns bytes read or written.
//! The target process must be accessible (same user or root).
//! Caller is responsible for ensuring the address range is valid.

const std = @import("std");
const linux = std.os.linux;

const iovec = std.posix.iovec;
const iovec_const = std.posix.iovec_const;

const zua = @import("zua");

/// Errors that can occur during process memory operations.
pub const Error = error{
    PartialTransfer,
    InvalidAddress,
    InvalidArgument,
    OutOfMemory,
    PermissionDenied,
    NoSuchProcess,
};

/// Reads typed values from a process's memory at the given address.
/// Context-free variant for use in background threads.
pub fn read(comptime T: type, pid: std.posix.pid_t, address: usize, buffer: []T) Error!void {
    if (buffer.len == 0) return;

    const local = [_]iovec{.{
        .base = @ptrCast(buffer.ptr),
        .len = buffer.len * @sizeOf(T),
    }};
    const remote = [_]iovec_const{.{
        .base = @ptrFromInt(address),
        .len = buffer.len * @sizeOf(T),
    }};
    try checkResult(linux.process_vm_readv(pid, &local, &remote, 0), buffer.len * @sizeOf(T));
}

/// Writes typed values into a process's memory at the given address.
/// Context-free variant for use in background threads.
pub fn write(comptime T: type, pid: std.posix.pid_t, address: usize, bytes: []const T) Error!void {
    if (bytes.len == 0) return;

    const local = [_]iovec_const{.{
        .base = @ptrCast(bytes.ptr),
        .len = bytes.len * @sizeOf(T),
    }};
    const remote = [_]iovec_const{.{
        .base = @ptrFromInt(address),
        .len = bytes.len * @sizeOf(T),
    }};
    try checkResult(linux.process_vm_writev(pid, &local, &remote, 0), bytes.len * @sizeOf(T));
}

/// Reads typed values with zua context for error reporting.
pub fn readTyped(comptime T: type, ctx: *zua.Context, pid: std.posix.pid_t, address: usize, buffer: []T) !void {
    read(T, pid, address, buffer) catch |err| return ctx.failWithFmt("{s}", .{@errorName(err)});
}

/// Writes typed values with zua context for error reporting.
pub fn writeTyped(comptime T: type, ctx: *zua.Context, pid: std.posix.pid_t, address: usize, bytes: []const T) !void {
    write(T, pid, address, bytes) catch |err| return ctx.failWithFmt("{s}", .{@errorName(err)});
}

fn checkResult(result: usize, expected_len: usize) Error!void {
    switch (linux.errno(result)) {
        .SUCCESS => {
            if (result != expected_len) return Error.PartialTransfer;
        },
        .FAULT => return Error.InvalidAddress,
        .INVAL => return Error.InvalidArgument,
        .NOMEM => return Error.OutOfMemory,
        .PERM => return Error.PermissionDenied,
        .SRCH => return Error.NoSuchProcess,
        else => return Error.InvalidArgument,
    }
}

test {
    std.testing.refAllDecls(@This());
}
