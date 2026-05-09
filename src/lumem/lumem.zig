//! Lumem is the root scripting object exposed to Lua as the global lumem.
//! It provides access to live process enumeration and other host-side utilities
//! for scripts and the interactive REPL.

const std = @import("std");
const zua = @import("zua");
const Meta = zua.Meta;
const Process = @import("process/process.zig");
const DataType = @import("mem/types.zig").DataType;
const Memory = @import("mem/memory.zig");

/// The top-level lumem object available in Lua.
const Lumem = @This();

pub const ZUA_META = Meta.Object(Lumem, .{
    .__tostring = display,
    .scan = scan,
    .get = get,
    .set = set,
}, .{
    .name = "Lumem",
    .description = "The root scripting object for process memory inspection.",
});


/// Scans live processes and returns a Process.List wrapper.
fn scan(ctx: *zua.Context, _: *Lumem, filter: ?Process.Filter) !Process.List {
    const _filter = filter orelse Process.Filter{};
    const procs = try Process.scanAll(ctx, &_filter);
    return try Process.List.init(ctx, procs);
}

fn get(ctx: *zua.Context, _: *Lumem, pid: std.posix.pid_t, address: usize, dataType: DataType) !zua.Decoder.Primitive {
    switch (dataType) {
        .Simple => |simple| switch (simple) {
            .U8 => return try readTyped(u8, ctx, pid, address),
            .U16 => return try readTyped(u16, ctx, pid, address),
            .U32 => return try readTyped(u32, ctx, pid, address),
            .U64 => return try readTyped(u64, ctx, pid, address),
            .I8 => return try readTyped(i8, ctx, pid, address),
            .I16 => return try readTyped(i16, ctx, pid, address),
            .I32 => return try readTyped(i32, ctx, pid, address),
            .I64 => return try readTyped(i64, ctx, pid, address),
            .F32 => return try readTyped(f32, ctx, pid, address),
            .F64 => return try readTyped(f64, ctx, pid, address),
        },
        .Aggregated => return ctx.failTyped(zua.Decoder.Primitive, "cannot read aggregated data type"),
    }
}

fn set(ctx: *zua.Context, _: *Lumem, pid: std.posix.pid_t, address: usize, dataType: DataType, value: zua.Mapper.Primitive) !void {
    switch (dataType) {
        .Simple => |simple| switch (simple) {
            .U8 => try writeTyped(u8, ctx, pid, address, value),
            .U16 => try writeTyped(u16, ctx, pid, address, value),
            .U32 => try writeTyped(u32, ctx, pid, address, value),
            .U64 => try writeTyped(u64, ctx, pid, address, value),
            .I8 => try writeTyped(i8, ctx, pid, address, value),
            .I16 => try writeTyped(i16, ctx, pid, address, value),
            .I32 => try writeTyped(i32, ctx, pid, address, value),
            .I64 => try writeTyped(i64, ctx, pid, address, value),
            .F32 => try writeTyped(f32, ctx, pid, address, value),
            .F64 => try writeTyped(f64, ctx, pid, address, value),
        },
        .Aggregated => try ctx.fail("cannot write aggregated data type"),
    }
}

fn display(ctx: *zua.Context, _: *Lumem) ![]const u8 {
    const text = "lumem: scriptable process memory inspector.\n" ++
        "Example:\n" ++
        "  processes = lumem:scan({name = \"target\"})\n" ++
        "  p = processes[1]\n" ++
        "  regions = p:regions(\"rw\")\n" ++
        "  entries = regions[1]:scan(\"u32\", {eq = 0})\n" ++
        "  value = lumem:get(pid, address, \"u32\")\n" ++
        "  lumem:set(pid, address, \"u32\", 33)\n" ++
        "You could also use raw memory operations without scanning:\n" ++
        "  value = lumem:get(pid, address, \"u32\")\n" ++
        "  lumem:set(pid, address, \"u32\", 33)\n" ++
        "Use tostring(lumem) to show this help again.";
    return std.fmt.allocPrint(ctx.arena(), "{s}", .{text}) catch ctx.failTyped([]const u8, "Out of memory");
}


fn readTyped(comptime T: type, ctx: *zua.Context, pid: std.posix.pid_t, address: usize) !zua.Decoder.Primitive {
    var bytes: [1]T = undefined;
    try Memory.readTyped(T, ctx, pid, address, &bytes);
    return switch (T) {
        u8, u16, u32, i8, i16, i32, i64 => .{ .integer = @intCast(bytes[0]) },
        u64 => blk: {
            const value = bytes[0];
            if (std.math.cast(i64, value)) |int_value| {
                break :blk .{ .integer = int_value };
            }
            break :blk .{ .float = @floatFromInt(value) };
        },
        f32 => .{ .float = @floatCast(bytes[0]) },
        f64 => .{ .float = @floatCast(bytes[0]) },
        else => @compileError("unsupported type"),
    };
}

fn writeTyped(comptime T: type, ctx: *zua.Context, pid: std.posix.pid_t, address: usize, value: zua.Mapper.Primitive) !void {
    const bytes: [1]T = .{try zua.Decoder.decodeValue(ctx, value, T)};
    try Memory.writeTyped(T, ctx, pid, address, &bytes);
}

test {
    std.testing.refAllDecls(@This());
}
