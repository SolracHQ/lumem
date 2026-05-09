# Changelog

## 0.2.0

### Changed

- Updated zua dependency from 0.8.0 to 0.13.0
- Source files reorganized: proc/ renamed to process/, mem files renamed
- Merged process scanner into process.zig
- Updated ZUA_META blocks to match zua 0.13 API

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
