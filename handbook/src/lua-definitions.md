# Lua definitions

Lumem ships with files that give your editor autocompletion and type checking for the entire API. Point LuaLS at the `stubs/` directory and you get descriptions, argument names, and return types for every method. No building, no setup besides pointing your editor at the right folder.

## Setup

Two files included in the repo:

- `stubs/lumem.d.lua` for the global `lumem` binding (CLI mode)
- `stubs/lumem.lib.d.lua` for `require("lumem")` (shared library mode)

Configure your editor's LuaLS to include `stubs/` in its path. That is it.

## What they look like

```lua
-- Scans live processes and returns a ProcList matching the optional filter.
---@param filter Filter? # Optional filter with pid, uid, name, or cmdLine fields.
---@return ProcList
function Lumem:scan(filter) end

-- Returns a Process for the current process.
---@return Process
function Lumem:self() end

-- Creates a typed Entry at a process memory address for reading and writing.
---@param config EntryConfig # Table with pid, address, type, and optional size for str.
---@return Entry
function Lumem:entry(config) end
```

Every method, argument, and return type is annotated. The definitions are generated from the library source code so they stay in sync.

## Updating

When you update lumem, the stubs in the repo are already up to date. If you build from source, regenerate them with:

```sh
just docs
```
