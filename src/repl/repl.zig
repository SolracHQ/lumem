//! Starts the interactive Lua REPL for exploratory work.

const std = @import("std");
const zua = @import("zua");

pub fn run(state: *zua.State) void {
    var config = zua.Repl.Config{
        .welcome_message = "Welcome to the Lumem REPL! Type 'lumem' for usage instructions.\n",
        .prompt = "lumem",
        .runtime_completion = true,
        .stack_trace = true,
        .history_path = "/tmp/.lumem_repl_history",
    };
    zua.Repl.run(state, &config) catch |err| {
        std.debug.print("REPL error: {s}\n", .{@errorName(err)});
    };
}
