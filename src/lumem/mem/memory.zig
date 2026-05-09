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

/// Reads typed values from a process's memory at the given address.
pub fn readTyped(comptime T: type, ctx: *zua.Context, pid: std.posix.pid_t, address: usize, buffer: []T) !void {
    if (buffer.len == 0) return;

    const local = [_]iovec{.{
        .base = @ptrCast(buffer.ptr),
        .len = buffer.len * @sizeOf(T),
    }};
    const remote = [_]iovec_const{.{
        .base = @ptrFromInt(address),
        .len = buffer.len * @sizeOf(T),
    }};
    try expectFullTransfer(ctx, linux.process_vm_readv(pid, &local, &remote, 0), buffer.len * @sizeOf(T));
}

/// Writes typed values into a process's memory at the given address.
pub fn writeTyped(comptime T: type, ctx: *zua.Context, pid: std.posix.pid_t, address: usize, bytes: []const T) !void {
    if (bytes.len == 0) return;

    const local = [_]iovec_const{.{
        .base = @ptrCast(bytes.ptr),
        .len = bytes.len * @sizeOf(T),
    }};
    const remote = [_]iovec_const{.{
        .base = @ptrFromInt(address),
        .len = bytes.len * @sizeOf(T),
    }};
    try expectFullTransfer(ctx, linux.process_vm_writev(pid, &local, &remote, 0), bytes.len * @sizeOf(T));
}

fn expectFullTransfer(ctx: *zua.Context, result: usize, expected_len: usize) !void {
    switch (linux.errno(result)) {
        .SUCCESS => {
            if (result != expected_len) {
                return ctx.failWithFmt("partial transfer: expected {d} bytes, got {d}", .{ expected_len, result });
            }
        },
        .FAULT => return ctx.failWithFmt("invalid address: {x}", .{result}),
        .INVAL => return ctx.failWithFmt("invalid argument: {x}", .{result}),
        .NOMEM => return ctx.failWithFmt("out of memory: {x}", .{result}),
        .PERM => return ctx.failWithFmt("access denied: {x}", .{result}),
        .SRCH => return ctx.failWithFmt("no such process: {x}", .{result}),
        else => return ctx.failWithFmt("unexpected error: {x}", .{result}),
    }
}

test {
    std.testing.refAllDecls(@This());
}
