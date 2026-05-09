const std = @import("std");

pub fn main() void {
    var health: i32 = 100;
    const pid = std.os.linux.getpid();
    std.debug.print("pid: {d}  &health: 0x{x}\n", .{ pid, @intFromPtr(&health) });
    while (true) {
        std.debug.print("health: {d}\n", .{health});
        var ts = std.os.linux.timespec{ .sec = 2, .nsec = 0 };
        _ = std.os.linux.nanosleep(&ts, null);
        health = if (health > 0) health - 1 else 100;
    }
}
