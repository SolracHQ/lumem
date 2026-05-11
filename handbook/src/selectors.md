# Selectors

Every `scan` and `filter` call takes a selector. It tells lumem what you are looking for.

> [!NOTE]
> Think of a selector like a metal detector. You tell it what kind of beep to make and it tells you where the treasure is.

## Table selectors

Pass a table with one key. The key names are straightforward.

```lua
{ eq = 42 }          -- equal to 42
{ ne = 0 }           -- not equal to 0
{ gt = 100 }         -- greater than 100
{ ge = 50 }          -- greater than or equal to 50
{ lt = 200 }         -- less than 200
{ le = 150 }         -- less than or equal to 150
{ range = { 50, 150 } }  -- between 50 and 150 inclusive
```

Only one key per selector. Zero keys or more than one is an error.

## String selectors

Strings work different from numbers. Instead of aligned reads it slides byte by byte looking for a match. Slower, but it finds text wherever it hides. Same `eq` and `ne` work here, plus two extras.

### Needle

You know the text you want but you also want the bytes around it. Maybe the player name sits between two markers and you want the whole thing. `needle` finds the exact bytes and gives you context on the sides.

```lua
-- find your name with surrounding bytes for context
{ needle = "current name", context = 15 }

-- 8 bytes to the left, 2 to the right
{ needle = "hp", bounds = { 8, 2 } }

-- just the needle, no context
{ needle = "kills" }
```

Long form if you prefer namespacing:

```lua
{ contains = { needle = "current name", context = 10 } }
```

### Delimited

You know what the data starts or ends with but not what is in the middle. Maybe a struct in memory begins with a known header and you want to grab the whole thing. `prefix` says "starts with", `suffix` says "ends with", `len` is how many bytes total.

```lua
-- dialog text between markers
{ prefix = "<text>", len = 64 }

-- pick up the whole player struct by its header
{ prefix = "PLAYER_DATA_START", len = 256 }

-- surround with both
{ prefix = "[", suffix = "]", len = 16 }
```

Long form:

```lua
{ delimited = { prefix = "<text>", len = 64 } }
```

These only work for string scans. Using them on numbers errors out.

Change tracking for strings only supports `"none"` and `"any"`. Increase and decrease make no sense for text so they error.

Custom predicates work on strings the same as on numbers. The callback gets the current string and the previous one (or nil on first scan).

## Custom predicates

The `custom` key gives you full control. The callback receives two arguments: the current live value and the previous cached value, or nil on the first scan. Return true to keep the entry.

```lua
entries = p:scan("u32", {
    custom = function(value, prev)
        return value % 2 == 0 and (prev == nil or value > prev)
    end,
})
```

This keeps only even numbers that increased since the last scan. The previous value is whatever was cached from the previous scan or filter call. On the first scan there is no previous value, so `prev` is nil. The condition above treats that as a match.

## Shorthand forms

A plain number is the same as `{ eq = x }`.

```lua
entries = r:scan("u32", 42)
-- same as r:scan("u32", { eq = 42 })
```

A plain Lua function is the same as `{ custom = f }`.

```lua
entries = r:scan("f64", function(v, _)
    return v > 0 and v < 1
end)
```

A plain string is the same as `{ eq = s }`.

```lua
entries = r:scan("str", "hello")
-- same as r:scan("str", { eq = "hello" })
```

## Change tracking

The `change` selector compares the current live value against the cached value. This is the main tool for narrowing results across multiple passes.

```lua
{ change = "increase" }   -- value went up
{ change = "decrease" }   -- value went down
{ change = "none" }       -- value stayed the same
{ change = "any" }        -- value changed at all
```

On the first scan there is no previous value, so every entry matches. That is fine because you are casting a wide net at the start. After that, each filter call re-reads every entry and keeps only those that match the change you care about.

A typical session looks like this:

```lua
local entries = p:scan("i32", { range = { 0, 1000 } })

for round = 1, 4 do
    os.execute("sleep 2")
    entries:filter({ change = "decrease" })
end

entries:set(9999)
```

Each round discards entries that did not decrease. By the end only the game timer remains, and you set it to something that never runs out.

## Permission filters

Some methods accept an optional permission filter as the last argument. This tells lumem which memory regions to search.

```lua
"rwxp"                       -- 4-char maps string
{ "read", "write" }         -- table of names
```

The default is readable and writable (`"rw--"`).

## Reference

| Form | Example | Description |
|------|---------|-------------|
| Table | `{ eq = 42 }` | Exact match |
| Table | `{ gt = 100 }` | Comparison |
| Table | `{ range = { lo, hi } }` | Inclusive range |
| Table | `{ needle = "abc", context = 10 }` | Find bytes with context (strings only) |
| Table | `{ contains = { needle, context } }` | Long form of needle (strings only) |
| Table | `{ prefix = "[", len = 16 }` | Delimited by prefix (strings only) |
| Table | `{ delimited = { prefix, suffix, len } }` | Long form of delimited (strings only) |
| Table | `{ change = "decrease" }` | Change tracking |
| Table | `{ custom = f }` | Custom predicate |
| Number | `42` | Shorthand for `{ eq = 42 }` |
| String | `"hello"` | Shorthand for `{ eq = "hello" }` |
| Function | `function(v) end` | Shorthand for `{ custom = f }` |
