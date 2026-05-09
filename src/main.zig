const std = @import("std");
const zua = @import("zua");
const repl = @import("repl/repl.zig");

const Lumem = @import("lumem").Lumem;

pub fn main(init: std.process.Init) !void {
    const state = try zua.State.init(init.gpa, init.io);
    defer state.deinit();

    var context = zua.Context.init(state);
    defer context.deinit();

    try state.addGlobals(&context, .{ .lumem = Lumem{} });

    const args = try init.minimal.args.toSlice(state.allocator);
    defer state.allocator.free(args);

    if (args.len == 2) {
        var executor = zua.Executor{};
        try executor.execute(&context, .{ .code = .{ .file = args[1] } });
        return;
    }

    try repl.run(state);
}
