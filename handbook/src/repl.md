# REPL

Running `lumem` with no arguments starts an interactive shell. This is where you play with memory in real time, test selectors, and figure out the right sequence before turning it into a script.

```sh
sudo ./zig-out/bin/lumem
```

You get a prompt with the `lumem` global already loaded, multiline input, tab completion, syntax highlighting. Type stuff, call methods, see what happens.

```
lumem> p = lumem:scan("game")
lumem> entries = p:scan("i32", { range = { 0, 100 } })
lumem> print(#entries)
42
```

## The local variable gotcha

Each line runs as its own Lua chunk. `local` at the top scope disappears when the line finishes.

```lua
p = lumem:scan("target")       -- this persists, use this
local p = lumem:scan("target") -- this disappears
```

Locals inside functions and blocks work normally. Only the top scope is affected. Rule: use bare assignment for anything you want to reference later.

## Multiline input

Press Shift+Tab to add a new line without executing.

```
lumem> for i = 1, 5 do         -- press Shift+Tab
  ...>     print(i)
  ...> end                     -- press Enter
1
2
3
4
5
```

## Tab completion and history

Tab completes globals, methods, and chained identifiers. Type `lumem:` and hit Tab to see available methods. History persists across sessions.

## A full exploratory session

The REPL is for discovery. You run one step at a time, inspect results, decide what to do next. Once you have the sequence, move it to a `.lua` script.

```
$ sudo ./zig-out/bin/lumem
lumem> p = lumem:scan("target")
lumem> regions = p:regions()
lumem> print(#regions .. " writable regions")
15 writable regions
lumem> entries = p:scan("i32", { range = { 0, 100 } })
lumem> print(#entries .. " initial matches")
42 initial matches
lumem> entries:filter({ change = "decrease" })
lumem> print(#entries .. " after decrease")
12 after decrease
lumem> entries:set(0)
```

Scripts are for repetition. The REPL is for figuring out what to script.

Ctrl-D or `os.exit()` to quit.
