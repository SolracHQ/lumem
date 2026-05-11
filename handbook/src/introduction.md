# Introduction

Lumem is a tool to inspect and modify the memory of running processes on Linux. You know Cheat Engine? Game Conqueror? Same idea but for the terminal and scriptable with Lua. I built it because I grew up using those tools and wanted something I could automate, something that did not need a GUI.

> [!NOTE]
> Lumem is only compatible with Lua 5.4.

Let me show you why this is useful. Do you have a game with a timer that always goes down and you want it to stop? You find it in memory, track it ticking down, freeze it. A session looks like this:

```lua
local p = lumem:scan("game")[1]
local entries = p:scan("i32", { range = { 0, 1000 } })

for round = 1, 4 do
    os.execute("sleep 2")
    entries:filter({ change = "decrease" })
end

entries:set(999)
entries:pin()  -- locks it in place
```

This is the core workflow. You scan, you filter, you write, you pin. Every chapter in this book builds on this.

Lumem works with any process on the same machine. You can also load it as a shared library from inside a game that supports Lua. No root needed when you inspect your own process.

## What this book covers

The chapters follow a natural progression. Read straight through or jump to whatever you need.

Glossary: concepts explained for people who never touched this stuff.

Process enumeration: finding the right target process.

Memory regions: how process memory is organized and how to inspect it.

Memory scanning: searching for typed values with selectors.

Selectors: the query language, comparisons, change tracking, custom predicates.

Entries: what happens after a scan, reading, writing, and filtering results.

Shared library: using lumem as a loadable module.

Lua definitions: editor autocompletion for the whole API.

REPL: the interactive shell and how to use it for exploratory work.

From source: building from source if you prefer that over prebuilt releases.
