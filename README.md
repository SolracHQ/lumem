# Lumem

Lumem is a scriptable process memory inspector and editor, driven by Lua.
A hobby project to learn Zig and Lua, and mess with game memory along the way.

If you just want to see what it can do, skip to [Usage](#usage).
For what is coming next, see [planning.md](planning.md).

## Motivation

I grew up using Cheat Engine on Windows and Game Conqueror on Linux. I always wanted to build something like it myself. This is the first attempt that made it past the prototype stage, and the language choices are why.

For the host language I had a specific set of requirements: full control over memory layout and allocation, no exceptions or hidden control flow, generics and a useful stdlib, and a build system that does not make linking third-party code a project of its own. Zig hits all of them. I also just wanted to take a closer look at the language, and this was a good excuse.

For the scripting layer I ruled out a UI early, partly because I wanted something different from existing tools and partly because I am not good at making them. A scripting language gives the user more power, and the first user is me, so I thought about what I would actually want. I chose Lua not because it is my favorite language (1-indexed arrays and `end` delimiters are not for me) but because it meets the requirements that actually matter for an embedded scripting language: genuinely easy to embed in a host program, lightweight, and supported by real tooling. LuaLS in particular is what puts it ahead of the many small embeddable languages that are only known by their creators.

## Status

- `lumem <script.lua>` boots Lua, registers globals, loads the script, and runs it.
- `lumem` with no arguments starts an interactive REPL with history and tab completion.
- `lumem:scan()` enumerates live processes with optional filtering.
- `ProcessList:get(index)` returns a `Process` object.
- `Process:scan()` scans all readable memory regions and returns matched entries.
- `ProcessList:scan()` scans one or more filtered processes and returns a combined `EntryList`.
- `EntryList:filter()` narrows a previous result with a selector.
- Individual entries support `get()` and `set()`.

## Usage

Run a script:

```sh
just run ./example/example.lua
```

Start the REPL:

```sh
just repl
```

In the REPL, top-level locals do not persist between lines. Use bare assignment instead:

```lua
-- this works across lines
res = lumem:scan({name = "target"})

-- this does not
local res = lumem:scan({name = "target"})
```

## API

```lua
-- scan processes, optionally filtered by name substring
local process_list = lumem:scan({name = "target"})
local process = process_list:get(1)

-- scan a single process
local entries = process:scan("f32", {eq = 8.3})
local entries = process:scan("u32", {range = {0, 255}})

-- scan a region
local regions = process:regions("rw")
local entries = regions[1]:scan("u32", {gt = 100})

-- scan a filtered process list
local entries = process_list:scan("u32", {eq = 123})

-- narrow down results
entries = entries:filter({eq = 9.0})
entries = entries:filter({range = {1.0, 10.0}})

-- read and write individual entries
print(entries[1]:get())
entries[1]:set(9.0)

-- write to all the entries at once
entries:set(9.0)

```

### Filter options

`lumem:scan({ ... })` supports process filters:
- `pid`: exact process ID match
- `uid`: exact user ID match
- `name`: substring match against the process name
- `cmdLine`: substring match against the command line

`Process:scan(type, selector)` and `EntryList:filter(selector)` support memory selectors:
- `eq`: exact match (`{eq = 123}`)
- `ne`: not equal (`{ne = 0}`)
- `gt`, `ge`, `lt`, `le`: numeric comparisons
- `range`: inclusive range (`{range = {50, 100}}`)
- `custom`: callback predicate (`{custom = function(value, prev_value) return value == 50 end}`)
- `change`: one of `"increase"`, `"decrease"`, `"none"`, or `"any"`

`custom` callbacks receive the scanned value as the first argument and the previous value as the second argument; if you only need the current value, you can ignore the second argument.

```lua
local entries = process:scan("u32", {
    custom = function(value, prev)
        return value % 2 == 0 and (prev == nil or value > prev)
    end,
})
```

## Example

Build and run the example target in one terminal:

```sh
zig cc example/target.c -o example/target.o
./example/target.o
```

Then run MemScript as root in another terminal:

```sh
just run ./example/example.lua
```

## License

MIT, see [LICENSE](LICENSE).