const std = @import("std");
const zua = @import("zua");
const lua = zua.Bindings.lua;
const Lumem = @import("lumem").Lumem;

export fn luaopen_lumem(L: *lua.State) c_int {
    var threaded: std.Io.Threaded = .init(std.heap.c_allocator, .{});
    const io = threaded.io();

    const state = zua.State.libState(L, std.heap.c_allocator, io, "lumem") catch return 0;
    var ctx = zua.Context.init(state);
    defer ctx.deinit();
    zua.Mapper.Encoder.push(&ctx, Lumem{}) catch return 0;
    return 1;
}
