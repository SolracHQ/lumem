const std = @import("std");

pub fn formatTable(ctx: anytype, fields: []const struct { key: []const u8, val: []const u8 }) ![]const u8 {
    var single: usize = 2;
    for (fields) |f| {
        single += f.key.len + f.val.len + 4;
    }

    if (single <= 50) {
        var out = std.ArrayList(u8).empty;
        try out.append(ctx.arena(), '{');
        for (fields, 0..) |f, i| {
            if (i > 0) try out.appendSlice(ctx.arena(), ", ");
            try out.appendSlice(ctx.arena(), f.key);
            try out.appendSlice(ctx.arena(), " = ");
            try out.appendSlice(ctx.arena(), f.val);
        }
        try out.append(ctx.arena(), '}');
        return out.items;
    }

    var out = std.ArrayList(u8).empty;
    try out.appendSlice(ctx.arena(), "{\n");
    for (fields) |f| {
        try out.appendSlice(ctx.arena(), "  ");
        try out.appendSlice(ctx.arena(), f.key);
        try out.appendSlice(ctx.arena(), " = ");
        try out.appendSlice(ctx.arena(), f.val);
        try out.appendSlice(ctx.arena(), ",\n");
    }
    try out.append(ctx.arena(), '}');
    return out.items;
}

pub fn truncate(s: []const u8, max: usize) []const u8 {
    if (s.len <= max) return s;
    return s[0..max];
}

pub fn quoted(arena: std.mem.Allocator, s: []const u8) ![]const u8 {
    var i: usize = 0;
    while (i < s.len) : (i += 1) {
        if (s[i] == '"' or s[i] == '\\' or s[i] == '\n' or s[i] == '\r' or s[i] == '\t') {
            var out = std.ArrayList(u8).empty;
            try out.append(arena, '"');
            for (s) |c| {
                switch (c) {
                    '"' => try out.appendSlice(arena, "\\\""),
                    '\\' => try out.appendSlice(arena, "\\\\"),
                    '\n' => try out.appendSlice(arena, "\\n"),
                    '\r' => try out.appendSlice(arena, "\\r"),
                    '\t' => try out.appendSlice(arena, "\\t"),
                    else => try out.append(arena, c),
                }
            }
            try out.append(arena, '"');
            return out.items;
        }
    }
    return std.fmt.allocPrint(arena, "\"{s}\"", .{s});
}
