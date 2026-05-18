//! Continuous memory write facility for pinned entries.
//!
//! PinWatcher keeps writing an entry's value to its address.
//! Pinned entries retain their value independently of the originating Entry object.

const std = @import("std");
const Io = std.Io;
const zua = @import("zua");
const Entry = @import("../mem/entry.zig");
const Memory = @import("../mem/memory.zig");
const SimpleType = @import("../mem/types.zig").SimpleType;

const Request = union(enum) {
    pin: struct { address: usize, pid: std.posix.pid_t, value: Entry.Value },
    unpin: struct { address: usize, data_type: SimpleType },
    shutdown,
};

const SharedState = struct {
    buf: [1024]Request,
    queue: Io.Queue(Request),
    io: Io,
    allocator: std.mem.Allocator,
};

/// Uniquely identifies a pinned entry by its address and data type.
pub const PinKey = struct {
    /// Virtual address of the entry in the target process.
    address: usize,
    /// The entry's scalar type. Used to reconstruct a typed write on unpin.
    data_type: SimpleType,
};

const PinnedEntry = struct { pid: std.posix.pid_t, value: Entry.Value };

/// Manages a set of entries that are continuously written to memory.
pub const PinWatcher = @This();

/// Heap-allocated state shared with the background thread.
/// Initialized in init(), freed by the background thread on shutdown.
state: *SharedState,
/// Background thread handle. Must be joined before the watcher is freed.
/// Joined in gc() after sending the shutdown signal.
thread: std.Thread,
/// Tracks which entries are currently pinned on the Lua side.
/// The background thread maintains its own copy of pinned entries.
pins: std.AutoHashMap(PinKey, void),

const methods = .{ .__gc = gc };

pub const ZUA_SHAPE = zua.Shape.Object(PinWatcher, methods, .{
    .name = "PinWatcher",
});

/// Returns a new PinWatcher.
pub fn init(allocator: std.mem.Allocator, io: Io) !PinWatcher {
    const shared = try allocator.create(SharedState);
    shared.* = .{
        .buf = undefined,
        .queue = undefined,
        .io = io,
        .allocator = allocator,
    };
    shared.queue = Io.Queue(Request).init(&shared.buf);
    const thread = try std.Thread.spawn(.{}, run, .{shared});
    return .{
        .state = shared,
        .thread = thread,
        .pins = .init(allocator),
    };
}

fn gc(_: *zua.Context, self: *PinWatcher) void {
    self.state.queue.putOneUncancelable(self.state.io, .shutdown) catch {};
    self.thread.join();
    self.pins.deinit();
}

/// Registers an entry for continuous writing.
pub fn pin(self: *PinWatcher, key: PinKey, req: Request) !void {
    try self.pins.put(key, {});
    try self.state.queue.putOneUncancelable(self.state.io, req);
}

/// Unregisters a pinned entry. Fails if the entry was never pinned.
pub fn unpin(self: *PinWatcher, ctx: *zua.Context, key: PinKey) !void {
    if (!self.pins.contains(key)) return ctx.fail("this entry is not pinned");
    _ = self.pins.remove(key);
    try self.state.queue.putOneUncancelable(self.state.io, .{ .unpin = .{ .address = key.address, .data_type = key.data_type } });
    if (self.pins.count() == 0) clearRegistry(ctx);
}

/// Gets the PinWatcher from the Lua registry, or null if none exists.
pub fn get(ctx: *zua.Context) ?*PinWatcher {
    const reg = ctx.state.registry();
    defer reg.release();
    return reg.get(ctx, "__lumem_pin_watcher", *PinWatcher) catch null;
}

/// Gets the PinWatcher from the Lua registry, or creates and stores one.
pub fn getOrCreate(ctx: *zua.Context) !*PinWatcher {
    if (get(ctx)) |w| return w;
    const w = try init(ctx.heap(), ctx.state.io);
    const reg = ctx.state.registry();
    defer reg.release();
    try reg.set(ctx, "__lumem_pin_watcher", w);
    return get(ctx) orelse return ctx.failTyped(*PinWatcher, "watcher init failed");
}

fn clearRegistry(ctx: *zua.Context) void {
    const reg = ctx.state.registry();
    defer reg.release();
    reg.set(ctx, "__lumem_pin_watcher", void{}) catch {};
}

fn writeEntry(address: usize, entry: PinnedEntry) void {
    switch (entry.value) {
        .u8 => |v| {
            const b = [_]u8{v};
            Memory.write(u8, entry.pid, address, &b) catch {};
        },
        .u16 => |v| {
            const b = [_]u16{v};
            Memory.write(u16, entry.pid, address, &b) catch {};
        },
        .u32 => |v| {
            const b = [_]u32{v};
            Memory.write(u32, entry.pid, address, &b) catch {};
        },
        .u64 => |v| {
            const b = [_]u64{v};
            Memory.write(u64, entry.pid, address, &b) catch {};
        },
        .i8 => |v| {
            const b = [_]i8{v};
            Memory.write(i8, entry.pid, address, &b) catch {};
        },
        .i16 => |v| {
            const b = [_]i16{v};
            Memory.write(i16, entry.pid, address, &b) catch {};
        },
        .i32 => |v| {
            const b = [_]i32{v};
            Memory.write(i32, entry.pid, address, &b) catch {};
        },
        .i64 => |v| {
            const b = [_]i64{v};
            Memory.write(i64, entry.pid, address, &b) catch {};
        },
        .f32 => |v| {
            const b = [_]f32{v};
            Memory.write(f32, entry.pid, address, &b) catch {};
        },
        .f64 => |v| {
            const b = [_]f64{v};
            Memory.write(f64, entry.pid, address, &b) catch {};
        },
        .str => |s| {
            Memory.write(u8, entry.pid, address, s) catch {};
        },
    }
}

fn freeValue(value: Entry.Value, allocator: std.mem.Allocator) void {
    if (value == .str) allocator.free(value.str);
}

fn run(shared: *SharedState) void {
    var bg_pins = std.AutoHashMap(PinKey, PinnedEntry).init(shared.allocator);
    defer {
        var it = bg_pins.iterator();
        while (it.next()) |e| freeValue(e.value_ptr.*.value, shared.allocator);
        bg_pins.deinit();
        shared.allocator.destroy(shared);
    }

    var buf: [16]Request = undefined;
    while (true) {
        const start = Io.Clock.now(.awake, shared.io);
        const count = shared.queue.get(shared.io, &buf, 0) catch break;
        var shut = false;
        for (buf[0..count]) |req| switch (req) {
            .pin => |p| {
                const key = PinKey{ .address = p.address, .data_type = std.meta.activeTag(p.value) };
                if (bg_pins.fetchRemove(key)) |kv| freeValue(kv.value.value, shared.allocator);
                bg_pins.put(key, .{ .pid = p.pid, .value = p.value }) catch {};
            },
            .unpin => |u| {
                const key = PinKey{ .address = u.address, .data_type = u.data_type };
                if (bg_pins.fetchRemove(key)) |kv| freeValue(kv.value.value, shared.allocator);
            },
            .shutdown => shut = true,
        };
        if (shut) break;
        var it = bg_pins.iterator();
        while (it.next()) |e| writeEntry(e.key_ptr.*.address, e.value_ptr.*);
        const elapsed = Io.Clock.now(.awake, shared.io).nanoseconds - start.nanoseconds;
        const rem = 50 * std.time.ns_per_ms - elapsed;
        if (rem > 0) shared.io.sleep(.fromNanoseconds(rem), .awake) catch break;
    }
}

test {
    std.testing.refAllDecls(@This());
}
