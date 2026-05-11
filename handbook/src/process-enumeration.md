# Process enumeration

Every memory inspection session starts with choosing a target process. That is the game you want to mess with, the program you want to look inside.

## Finding processes

`lumem:scan()` returns a list of running processes. Without arguments it returns everything, but you almost always filter.

```lua
local procs = lumem:scan()
```

The most common filter is a name. Pass a string and lumem matches it against each process name. It is a substring match so `"firefox"` finds any process with "firefox" in the name.

```lua
local procs = lumem:scan("firefox")
```

For more precision, pass a table. You can filter by name, pid, uid, or command line. All non-nil fields must match.

```lua
local procs = lumem:scan({ name = "firefox" })
local procs = lumem:scan({ pid = 1234 })
local procs = lumem:scan({ uid = 1000 })
local procs = lumem:scan({ name = "nginx", cmdLine = "worker" })
```

The `name` and `cmdLine` fields use substring matching. `pid` and `uid` use exact equality.

## Accessing results

The returned list works like a Lua array. Index it, take its length, iterate it.

```lua
local procs = lumem:scan("target")

if #procs == 0 then
    print("process not found")
    return
end

local p = procs[1]
```

To iterate use the `iter` method. It gives you the index and the element on each step.

```lua
for i, p in procs:iter() do
    print(i, p:get_name())
end
```

This works for all list types in lumem: process lists, region lists, entry lists.

## Process information

Each process exposes its metadata through getters.

| Method | Returns | Notes |
|--------|---------|-------|
| `p:get_pid()` | number | Numeric process ID |
| `p:get_name()` | string | Process name |
| `p:get_cmd_line()` | string | Full command line |
| `p:get_parent_pid()` | number or nil | Parent process ID |
| `p:get_uid()` | number or nil | User ID |
| `p:get_gid()` | number or nil | Group ID |

Parent PID, UID, and GID can be nil. Check for nil before using them.

## Narrowing a list

`ProcList:filter()` takes the same filter fields as `lumem:scan()` and removes non-matching processes in place.

```lua
procs:filter({ pid = 1234 })
```

Useful when you already have a list and want to narrow it without scanning again. Use `clone` first if you need to keep the original.

```lua
local backup = procs:clone()
procs:filter({ pid = 1234 })
```

## The current process

`lumem:self()` returns a process object for the same process running lumem. No root needed because you are just reading your own info. Useful when loading as a shared library from inside a game.

```lua
local self = lumem:self()
print(self:get_name(), self:get_pid())
```

The [Shared library](./shared-library.md) chapter covers this.
