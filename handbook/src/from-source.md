# From source

Prebuilt binaries and shared libraries are in the [GitHub releases](https://github.com/SolracHQ/lumem/releases) section. Grab those if you just want to use the tool. If you want to build from source, you need a Zig 0.16 compiler.

```sh
zig build
```

This produces `zig-out/bin/lumem`. For the shared library:

```sh
zig build dylib && cp zig-out/lib/liblumem.so lumem.so
```

Releases include `lumem.so` ready to use so you usually do not need to build it.

## Running scripts

Reading and writing another process's memory requires admin access. Run with `sudo` or `doas`:

```sh
sudo ./zig-out/bin/lumem script.lua
```

The only exception is `lumem:self()` which reads the same process running lumem. No root needed for that. More in the [Shared library](./shared-library.md) chapter.

## REPL

Running `lumem` with no arguments starts an interactive shell for live memory editing.

```sh
sudo ./zig-out/bin/lumem
```

History, tab completion, syntax highlighting. Ctrl-D to exit.

> [!NOTE]
> Local variables declared at the top scope do not persist between REPL lines. Use bare assignments for values you want to reference later. The [REPL](./repl.md) chapter explains this.
