const std = @import("std");
const zua = @import("zua");
const Lumem = @import("lumem").Lumem;

pub fn main(init: std.process.Init) !void {
    var buf: [4096]u8 = undefined;
    var file_writer = std.Io.File.Writer.init(.stdout(), init.io, &buf);
    const writer = &file_writer.interface;

    const args = try init.minimal.args.toSlice(init.gpa);
    defer init.gpa.free(args);

    if (args.len >= 2 and std.mem.eql(u8, args[1], "--lib")) {
        const stubs = try zua.Docs.generateModule(init.gpa, Lumem{}, "lumem");
        defer init.gpa.free(stubs);
        try writer.writeAll(stubs);
    } else {
        var gen = zua.Docs.init(init.gpa);
        defer gen.deinit();
        try gen.addBinding("lumem", Lumem{});
        const stubs = try gen.generate();
        try writer.writeAll(stubs);
    }
    try writer.flush();
}
