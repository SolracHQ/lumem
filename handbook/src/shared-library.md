# Shared library

Lumem can be loaded as a shared library with `require("lumem")`. This lets you use it from any Lua interpreter or inject it into a game that supports Lua scripting. The main trick: when loaded this way, `lumem:self()` gives you the game's own process without needing root.

## Loading

```lua
local lumem = require("lumem")
```

Releases include `lumem.so` ready to use. If you built from source, copy it to the right name:

```sh
cp zig-out/lib/liblumem.so lumem.so
```

Then place it where Lua can find it. Lua searches for modules in paths listed in `package.cpath`. If the file is in the same directory as your script, add that directory to the search path:

```lua
package.cpath = package.cpath .. ";./?.so"
local lumem = require("lumem")
```

The `?.so` pattern means "replace the question mark with the module name."

One small thing: `require` returns two values, the second being the path to the `.so` file. Assign to a single variable and the second value is discarded automatically. Or be explicit:

```lua
local lumem, _ = require("lumem")  -- explicit discard
```

## Inspecting your own process

When loaded as `lumem.so` inside a game, `lumem:self()` returns the game's own process. No root needed.

```lua
local lumem = require("lumem")
local self = lumem:self()

print(self:get_name(), self:get_pid())

-- read memory mappings
local regions = self:regions()
for i = 1, #regions do
    local r = regions[i]
    print(r:get_start(), r:get_end(), r:get_pathname())
end

-- scan your own writable memory
local entries = self:scan("u32", { range = { 0, 100 } })
print(#entries, "u32 values in 0-100 range")
```

This is the only mode that works without root. You are limited to your own address space.

## Accessing other processes

You can still scan other processes through `lumem:scan()` and `lumem:entry()` when loaded as a dylib. Those calls require root.

## Building

Releases include `lumem.so` ready to use. If you build from source:

```sh
zig build dylib && cp zig-out/lib/liblumem.so lumem.so
```
