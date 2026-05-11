# Lumem

Lumem is a Lua-based tool to inspect and modify the memory of running processes on Linux.

I built it for those that, like me, prefer a REPL and a terminal over a graphical interface. Lua gives you the full power of a real programming language to automate memory modification, build your own tools, and tap into the Lua ecosystem. Lumem works as a standalone Lua environment with a single extra global variable, or as a shared library that just needs a `require` to embed in any Lua runner.

## Quick start

```sh
# terminal 1: run the example target process
just target

# terminal 2: run the example script
just run example/example.lua
```

## Workflow

```lua
-- find the process
local p = lumem:scan("game")[1]

-- scan for a value
local entries = p:scan("i32", { range = { 0, 1000 } })

-- track changes over time
for round = 1, 4 do
    os.execute("sleep 2")
    entries:filter({ change = "decrease" })
end

-- write and lock
entries:set(999)
entries:pin()
```

```sh
just run script.lua
```

Or run without arguments for the REPL:

```sh
just run
```

## Features

Explore running processes and filter by name, pid, uid, or what is on the command line. Then inspect their memory regions to see permissions and mapped files. Scan memory with any type from u8 to f64 to strings. Use aggregated aliases like "number" or "int" when you are not sure what you are looking for.

Match values with eq, ne, comparisons, ranges, or write your own Lua predicate. Track how values change over time with the change selector. Narrow results across multiple rounds like a classic cheat engine workflow.

Create entries manually for addresses you already know. Read and write from Lua. Pin an entry to keep its value in place across ticks.

All of it works on single entries or whole lists: set, filter, clone, pin, unpin in one call. The REPL gives you history, tab completion, multiline input, and syntax highlighting. Run `just docs` to generate Lua type stubs for your editor.

## Also a shared library

```sh
just dylib
```

```lua
local lumem = require("lumem")
local self = lumem:self()
```

Useful when the target process can load Lua modules. No root needed for self-inspection.

## License

MIT, see [LICENSE](LICENSE).
