# Changelog

## 0.2.0

### Breaking

- `lumem:get()` and `lumem:set()` removed. Use `lumem:entry()` then `entry:get()` / `entry:set()` instead
- `EntryList:filter()` and `ProcList:filter()` now modify in place instead of returning a new list
- Renamed Lua methods to snake_case following the LuaRocks style guide

### Added

- `lumem:self()` returns the current process
- `lumem:entry({ pid, address, type, size })` creates a typed entry, table-based config with optional size for str
- `zig build docs` generates Lua type stubs to stdout
- `just docs` saves stubs to `stubs/lumem.d.lua`
- `example/target.zig` example target process for testing scans
- `zig build target` builds and runs the example target
- `zig build dylib` builds the shared library (liblumem.so) for use with require("lumem")
- `just dylib` builds and copies to lumem.so

### Changed

- Updated zua dependency from 0.8.0 to 0.13.0
- Source files reorganized: proc/ renamed to process/, mem files renamed
- Merged process scanner into process.zig
- Updated ZUA_META blocks to match zua 0.13 API
- All Lua methods now include descriptions and argument documentation
- SimpleType enum variants renamed to lowercase (U8 -> u8, etc.)
- String type support added: scan memory with "string" type, contains/prefix selectors, read and write string entries
- Display overhaul: Process, Region, Entry, and all list types now show rich formatted tables with all fields
- EntryList display shows type summary and live vs cached values
- Entry filter now updates cached value after reading, so display reflects current state
- matches() signature changed from *const Entry to *Entry
- Best-effort strategy on bulk methods: set() continues on errors and reports a summary, filter() skips entries that error
- clone() added to ProcList, RegionList, and EntryList
- EntryList supports + operator (__add) to merge two lists

## 0.1.0

Rebuilt the API from the ground up using Zua for Lua binding and REPL support.

### Changed

- Replaced the old root `mem` table with `lumem` as a userdata-only entry point
- Moved all API access to Lua methods on `lumem` and process objects
- Switched lists to raw Lua lists backed by self-referential objects, enabling `:iter()` and aggregated operations
- Delegated REPL complexity entirely to Zua, including multiline input, history, and syntax highlighting
- Made input decoding flexible through Zua hooks, removing manual stack access (`-1`, `-2`, etc.)
- Scan selectors are now much more powerful and can use callback predicates
- Wrote the API with explicit type control so users can choose write types directly

### Added

- Syntax highlighting in the REPL via Zua's built-in tooling
- More flexible read/write APIs with typed access from Lua

## 0.0.2

Process inspection, memory scanning, and an interactive REPL.

### Added

- `proc.list()` enumerates live Linux processes, with optional name substring filtering
- `process:regions()` lists memory regions parsed from `/proc/<pid>/maps`, with optional perms filtering
- `process:scan()` scans all readable regions in one call, returns matched entries
- `region:scan()` scans a single region
- `entries:rescan()` filters a previous scan result by a new condition
- Entry objects with `get()` and `set()` for reading and writing values in the target process
- Scan conditions: exact match with `eq`, range match with `in_range`
- Supported types: `u8`, `u16`, `u32`, `u64`, `i8`, `i16`, `i32`, `i64`, `f32`, `f64`, and the
  aliases `number` (f64), `float` (f32), `int` (i32), `uint` (u32)
- Hex string support for address arguments in `mem.read_u32` and `mem.write_u32`
- Interactive REPL with history, tab completion, and multiline input
- REPL workspace that makes top-level assignments persist across lines without `local`
- `.help` command in the REPL

## 0.0.1

First working prototype.

### Added

- Basic CLI entry point that loads and runs a Lua script
- Minimal Lua wrapper around the system Lua 5.4 headers
- Global Lua `mem` table with `read_u32(pid, address)` and `write_u32(pid, address, value)`
- Linux process memory access through `process_vm_readv` and `process_vm_writev`
- Working example using `example/target.c` and `example/example.lua`
- `justfile` for common build, run, test, and cleanup tasks
