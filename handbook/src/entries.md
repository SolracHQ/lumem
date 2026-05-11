# Entries

An entry is one value at one address in one process. You get entries from scans, which return lists of them. You can also create one directly if you already know the address.

## Entry from a scan

When you call `scan`, the result is an `EntryList`. It behaves like a Lua array. Index it, take its length, iterate it.

```lua
local entries = p:scan("u32", { range = { 0, 100 } })
print(#entries)      -- how many matches
local first = entries[1]
```

Each entry carries metadata from the scan. You can read it without reading memory again.

```lua
e:get_address()    -- where it lives
e:get_pid()        -- which process
e:get_perms()      -- permissions at this address
```

## Manual entries

If you already know the pid, address, and type, create an entry directly without scanning.

```lua
local e = lumem:entry({ pid = pid, address = 0x7fff1234, type = "u32" })
```

Same `:get()` and `:set()` methods as scanned entries. Manual entries assume the address is readable and writable. Aggregated types like `"number"` are not supported here, use a specific type.

```lua
local e = lumem:entry({ pid = pid, address = address, type = "u32" })
e:set(42)
print(e:get())  -- 42
```

For string entries you need a `size` field.

```lua
local e = lumem:entry({ pid = pid, address = address, type = "str", size = 32 })
```

## Reading live values

`get` reads the current value from the target process. It might have changed since the scan.

```lua
local v = e:get()
```

The returned value matches the entry's type. If the bytes changed, they get reinterpreted according to the original type.

## Writing values

`set` writes a new value to the entry's address. Must be compatible with the entry's type. Writing a string to a `u32` entry fails. Writing to a non-writable region fails.

```lua
e:set(150)
```

## Bulk writes

Entry lists have a `set` method that writes the same value to every entry.

```lua
entries:set(0)
```

If some writes fail, the rest still execute. A summary is reported like `"wrote 10 of 12 entries (2 failed)"`.

## Filtering entries

`EntryList:filter()` re-reads every entry and removes those that do not match the selector. Modifies the list in place.

```lua
entries:filter({ change = "increase" })
entries:filter({ range = { 50, 100 } })
entries:filter({
    custom = function(v, prev)
        return v > 150
    end,
})
```

Each call re-reads every surviving entry. The previous value advances each time, which is what makes multi-round decrease tracking work.

Use `clone` first if you need the original for branching:

```lua
local snapshot = entries:clone()
entries:filter({ change = "increase" })
snapshot:filter({ change = "decrease" })
```

## Chaining

Filter modifies in place so just call it in sequence. Typical session: one broad scan, several rounds of change tracking, write the result, pin it.

```lua
local p = lumem:scan("target")[1]
local entries = p:scan("i32", { range = { 0, 1000 } })

for round = 1, 4 do
    os.execute("sleep 2")
    entries:filter({ change = "decrease" })
    print(#entries .. " remaining")
end

entries:set(42)
entries:pin()  -- game keeps it there
```

This is the core workflow: scan, narrow, write, pin.

## Display

`tostring()` on an entry list shows a table with address and value for up to 20 entries.

```lua
print(entries)
-- EntryList(3 entries)
-- index address           value
--     1 0x00007ffc12340000 u32(100)
--     2 0x00007ffc12340004 u32(42)
--     3 0x00007ffc12340008 u32(0)
```

## Pinning entries

`pin` keeps writing the entry's value to its address. Setting once is not enough when the game keeps changing it.

```lua
entry:pin()
entry:pin(99999)  -- pick a value right here
```

No value argument means it pins whatever the entry currently holds.

Pin infinite lives: find the counter, set it to 99, pin it, every death you keep going. Pin a timer at 999 and the clock stops. Pin currency or points at a reasonable amount, buy what you need, close lumem and nobody notices.

Call `unpin` when you are done.

```lua
entry:unpin()
```

Trying to unpin an entry that was never pinned raises an error.

## Bulk pin and unpin

Entry lists have `pin` and `unpin` that work on every entry at once.

```lua
entries:pin()
entries:pin(99999)
entries:unpin()
```

If some entries fail, the rest still execute. A summary is reported like `"pinned 10 of 12 entries (2 failed)"` or `"unpinned 10 of 12 entries (2 failed)"`.
