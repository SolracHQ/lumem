# Memory scanning

Scanning is how you search for values in a process's memory. You pick a data type and a selector, and lumem reads through the process's memory, testing each value against your criteria. The result is a list of entries that matched.

## Where to scan

You can scan at four levels depending on how narrow you want the search.

A single region is the fastest. If you already know roughly where the data lives, scan just that region.

```lua
local entries = r:scan("u32", { range = { 0, 100 } })
```

A region list scans every region in the list and merges results. Useful when you pre-filtered by permissions.

```lua
local entries = regions:scan("u32", { range = { 0, 100 } })
```

A process scans all readable and writable regions by default. Use this when you know the value exists somewhere but not where.

```lua
local entries = p:scan("u32", { range = { 0, 100 } })
```

A process list scans every process in the list and merges results. Useful when the same value appears in multiple instances of the same game.

```lua
local entries = procs:scan("u32", { eq = 42 })
```

You can also pass a permission filter as the last argument if you want to override the default writable-only behavior.

```lua
local entries = p:scan("u32", { eq = 42 }, { "read", "write" })
```

## Data types

If you know what kind of value you are looking for, pick a specific type and scan fast. On emulated games (GBA, NDS) most counters use `u8` or `i8`. On browser games, `f64` is the default number type. Picking the right type means lumem reads once and comes back nearly instantly.

| Lua name | Meaning |
|----------|---------|
| `"u8"` | unsigned 8-bit |
| `"u16"` | unsigned 16-bit |
| `"u32"` | unsigned 32-bit |
| `"u64"` | unsigned 64-bit |
| `"i8"` | signed 8-bit |
| `"i16"` | signed 16-bit |
| `"i32"` | signed 32-bit |
| `"i64"` | signed 64-bit |
| `"f32"` | 32-bit float |
| `"f64"` | 64-bit float |
| `"str"` | text (max 80 bytes) |

String scanning is slower than numeric types because it searches byte by byte, but it finds text wherever it hides.

```lua
-- find the health text exactly
local entries = p:scan("str", { eq = "health" })

-- misspelled your name and want to change it?
local entries = p:scan("str", { needle = "current name", context = 10 })

-- want to change your companion emote?
local entries = p:scan("str", { prefix = "emote_", len = 20 })
```

Strings over 80 bytes raise an error.

### Aggregated type aliases

Not sure what box the programmer used? Use an aggregated alias and scan them all at once.

| Alias | Scans |
|-------|-------|
| `"number"` | all 10 types |
| `"integer"` | all 8 integer types |
| `"signed"` or `"int"` | i8, i16, i32, i64 |
| `"unsigned"` or `"uint"` | u8, u16, u32, u64 |
| `"float"` | f32, f64 |

```lua
local entries = p:scan("number", { eq = 100 })
```

The tradeoff is time. Scanning all integer types reads each address eight times instead of once. Aggregated scans also return separate entries for each matching type at the same address. If address `0x1234` contains both `u32(100)` and `i32(100)`, both appear.

## Selectors

The second argument to `scan` describes what values to keep. Exact match, comparison, range.

```lua
local e = r:scan("u32", { eq = 0x1234 })
local e = r:scan("u32", { gt = 100 })
local e = r:scan("u32", { range = { 50, 150 } })
local e = r:scan("u32", { ne = 0 })
```

There are also shorthand forms. A plain number is the same as `{ eq = x }`. A plain function is the same as `{ custom = f }`.

```lua
local e = r:scan("u32", 42)
local e = r:scan("u32", function(v, _)
    return v > 100 and v % 2 == 0
end)
```

Selectors have their own chapter. See [Selectors](./selectors.md).

## How scanning works

Scan speed depends on the size of the target regions, the data type, the selector complexity, and whether you use aggregated types.

Custom Lua predicates are slower than built-in comparisons. If you can express what you want with `eq`, `gt`, `range`, or `change`, use those. Save `custom` for logic they cannot express.

> [!NOTE]
> Scan performance depends on how large the target regions are. Narrowing the search with permission filters (see [Memory regions](./memory-regions.md)) reduces scan time significantly. If you are curious about low-level details: processors require values to be at addresses divisible by their size. A `u32` (4 bytes) must be at an address divisible by 4. Lumem takes advantage of this and skips unaligned addresses. This is fine because unaligned values are usually garbage or would crash the target if read incorrectly.
