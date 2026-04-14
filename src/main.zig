const std = @import("std");
const zua = @import("zua");
const repl = @import("repl/repl.zig");

const Lumem = @import("lumem").Lumem;

pub fn main(init: std.process.Init) !void {
    const state = try zua.State.init(init.gpa, init.io);
    defer state.deinit();

    const globals = state.globals();
    defer globals.release();

    var context = zua.Context.init(state);
    defer context.deinit();

    globals.set(&context, "lumem", Lumem{});

    try repl.run(state);
}
