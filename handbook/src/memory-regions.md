# Memory regions

A process's memory is divided into regions.

> [!NOTE]
> Think of regions like rooms in a house. The code your game runs is in one room, the numbers it stores (health, gold, position) are in another. Each room has its own permissions. Some you can read and write, some you can only read, some are locked.

## Listing regions

```lua
local regions = p:regions()
```

Without arguments this returns all readable and writable regions. You can filter by permissions:

```lua
local rw = p:regions({ "read", "write" })
local all = p:regions({ "read", "write", "execute" })
```

You can also pass a permission string like `"rwxp"` where each character means read, write, execute, private.

```lua
local rw = p:regions("rwxp")
```

> [!NOTE]
> In most cases you only need readable and writable regions. Executable regions contain code, not data. Scanning them for a health value is a waste of time.

## Region metadata

Each region tells you its address range, size, permissions, and what file it maps (if any). Anonymous regions with no pathname are usually where the game stores its variables. That is where you want to look.

```lua
local r = regions[1]

r:get_start()      -- start address
r:get_end()        -- end address
r:get_size()       -- size in bytes
r:get_offset()     -- file offset
r:get_inode()      -- inode, 0 for anonymous
r:get_pathname()   -- mapped file, empty for anonymous
r:get_perms()      -- permissions, prints as "rwxp"
```

Printing a region shows all its fields:

```lua
print(r)
-- {
--   start = 0x7f...,
--   end = 0x7f...,
--   size = 4096,
--   perms = rw-p,
--   pathname = "/usr/lib/libc.so",
-- }
```

A region with pathname `/usr/lib/libc.so` is the C library, not your game data. A region with no pathname (anonymous) is often where the game stores its variables. That is your target.

## Scanning a region

The fastest way to find values is to scan a single region when you already know roughly where the data lives. Every region has its own `scan` method.

```lua
local entries = r:scan("u32", { range = { 0, 100 } })
```

Same data types and selectors as process-level scanning. See [Memory scanning](./memory-scanning.md) for the full list.

## Scanning all regions at once

A region list can scan all its regions and merge results into one entry list. This is what `Process:scan()` does internally.

```lua
local regions = p:regions({ "read", "write" })
local entries = regions:scan("i32", { range = { 0, 1000 } })
```
