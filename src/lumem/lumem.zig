//! Root scripting object exposed to Lua as the global lumem.
//!
//! Provides process enumeration, memory inspection via entry objects,
//! and access to the current process through lumem:self().

const std = @import("std");
const zua = @import("zua");
const Meta = zua.Meta;
const Process = @import("process/process.zig");
const DataType = @import("mem/types.zig").DataType;
const Entry = @import("mem/entry.zig").Entry;
const Permissions = @import("region/perms.zig").Permissions;

/// The top-level lumem object available in Lua.
const Lumem = @This();

const methods = .{
    .__tostring = m_display,
    .self = zua.Native.new(m_self, .{}, .{
        .description = "Returns a Process for the current process. No root needed, useful when loaded via require(\"lumem\").",
    }),
    .scan = zua.Native.new(m_scan, .{}, .{
        .description = "Scans live processes and returns a ProcList matching the optional filter.",
        .args = &.{
            .{ .name = "filter", .description = "Optional filter with pid, uid, name, or cmdLine fields." },
        },
    }),
    .entry = zua.Native.new(m_entry, .{}, .{
        .description = "Creates a typed Entry at a process memory address for reading and writing.",
        .args = &.{
            .{ .name = "config", .description = "Table with pid, address, type, and optional size for str." },
        },
    }),
};

pub const ZUA_META = Meta.Object(Lumem, methods, .{
    .name = "Lumem",
    .description = "The root scripting object for process memory inspection. Provides scan, entry, and self.",
});

/// Scans live processes and returns a ProcList matching the optional filter.
fn m_scan(ctx: *zua.Context, _: *Lumem, filter: ?Process.Filter) !Process.List {
    const _filter = filter orelse Process.Filter{};
    const procs = try Process.scanAll(ctx, &_filter);
    return try Process.List.init(ctx, procs);
}

/// Returns a Process for the current process. No root needed.
fn m_self(ctx: *zua.Context, _: *Lumem) !Process {
    return Process.getSelf(ctx);
}

/// Creates a typed Entry at a process memory address for reading and writing.
fn m_entry(ctx: *zua.Context, _: *Lumem, config: EntryConfig) !Entry {
    const simple = switch (config.type) {
        .Simple => |s| s,
        .Aggregated => return ctx.failTyped(Entry, "cannot create entry for aggregated data type"),
    };
    return Entry{
        .pid = config.pid,
        .address = config.address,
        .perms = .{ .bits = @intFromEnum(Permissions.Permission.read) | @intFromEnum(Permissions.Permission.write) },
        .value = switch (simple) {
            .u8 => Entry.Value{ .u8 = 0 },
            .u16 => Entry.Value{ .u16 = 0 },
            .u32 => Entry.Value{ .u32 = 0 },
            .u64 => Entry.Value{ .u64 = 0 },
            .i8 => Entry.Value{ .i8 = 0 },
            .i16 => Entry.Value{ .i16 = 0 },
            .i32 => Entry.Value{ .i32 = 0 },
            .i64 => Entry.Value{ .i64 = 0 },
            .f32 => Entry.Value{ .f32 = 0 },
            .f64 => Entry.Value{ .f64 = 0 },
            .str => value: {
                const size = config.size orelse return ctx.failTyped(Entry, "size required for str type");
                break :value Entry.Value{ .str = try ctx.heap().alloc(u8, size) };
            },
        },
    };
}

/// Formats the Lumem object with usage help for Lua tostring().
fn m_display(_: *zua.Context, _: *Lumem) []const u8 {
    return "lumem: scriptable process memory inspector.\n" ++
        "Example:\n" ++
        "  processes = lumem:scan({name = \"target\"})\n" ++
        "  p = processes[1]\n" ++
        "  regions = p:regions(\"rw\")\n" ++
        "  entries = regions[1]:scan(\"u32\", {eq = 0})\n" ++
         "  e = lumem:entry({ pid = pid, address = address, type = \"u32\" })\n" ++
        "  e:set(33)\n" ++
        "  value = e:get()\n" ++
        "Use tostring(lumem) to show this help again.";
}

const EntryConfig = struct {
    pid: std.posix.pid_t,
    address: usize,
    type: DataType,
    size: ?usize = null,

    pub const ZUA_META = zua.Meta.Table(EntryConfig, .{}, .{
        .name = "EntryConfig",
        .description = "Configuration for lumem:entry().",
        .field_descriptions = .{
            .pid = "Target process ID.",
            .address = "Memory address.",
            .type = "Data type string (\"u8\", \"i32\", \"str\", etc.).",
            .size = "Required for str type. Buffer size in bytes.",
        },
    });
};

test {
    std.testing.refAllDecls(@This());
}
