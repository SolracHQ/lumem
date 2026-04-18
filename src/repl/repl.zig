//! Thin wrapper that delegates to Zua's built-in REPL.

const zua = @import("zua");

pub fn run(state: *zua.State) !void {
    try zua.Repl.run(state, .{
        .welcome_message = "Welcome to the Lumem REPL! Type 'lumem' for usage instructions.\n",
        .prompt = "lumem> ",
        .continuation_prompt = "  ...> ",
    });
}
