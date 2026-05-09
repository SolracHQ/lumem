const std = @import("std");
const zua = @import("zua");
const Lumem = @import("lumem").Lumem;

pub fn main(init: std.process.Init) !void {
    var buf: [4096]u8 = undefined;
    var file_writer = std.Io.File.Writer.init(.stdout(), init.io, &buf);
    const writer = &file_writer.interface;

    var gen = zua.Docs.init(init.gpa);
    defer gen.deinit();
    try gen.addBinding("lumem", Lumem{});
    const stubs = try gen.generate();
    try writer.writeAll(stubs);
    try writer.flush();
}
