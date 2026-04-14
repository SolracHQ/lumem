//! Thin wrapper that delegates to Zua's built-in REPL.

const zua = @import("zua");

pub fn run(state: *zua.State) !void {
    try zua.Repl.run(state, .{});
}
