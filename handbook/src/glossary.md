# Glossary

Quick explanations for the concepts you need to know to follow the book. If you already know how operating systems handle memory you can skip this, but if terms like "process" or "address" are new, start here.

I wrote this for my past teenage self, the one who just wanted to cheat on games and did not know any of this. If that sounds like you, you are in the right place.

## Process

A process is a program running on your computer. Plague Inc, MelonDS, Firefox, Discord, every window you have open is one or more processes. When you open Task Manager or run `top` in a terminal, you are looking at the list of running processes.

Each process has its own memory space. That memory space contains the game's code, the current health of your units, the timer, the gold counter, the position of the player character, and everything else the game needs to keep track of. When you use lumem, you pick a process, search through its memory, and modify the values you find.

## Address

An address is like your home address but for data inside a process. It tells lumem exactly where the value you want to modify lives. If the address is `0x7fff1234`, think of it as "street name 0x7fff, house number 1234".

When you scan memory and find a value, lumem tells you its address so you can go back to it later and read or write it again.

## Region

A process's memory is not one big flat space. It is divided into regions, like a city divided into neighborhoods. Each region is a block of memory with specific permissions. Some neighborhoods are for code (executable), some are for data like numbers and strings (readable and writable), some are for graphics or loaded libraries.

When you scan a process, lumem only looks at readable and writable regions. Searching code regions for a health value would be like looking for your homework in the fridge. The code is instructions, not data.

Regions have metadata you can inspect: start and end addresses, size, permissions, and sometimes a pathname pointing to the file that was mapped there. A region with pathname `/usr/lib/libc.so` is the standard C library, not your game data. A region with no pathname (anonymous) is often where the game stores its variables.

## Data type

Values in memory are just numbers, but computers are often more complicated than that. RAM is expensive (specially since some AI company said they would buy it all and now it costs 4x more), so programmers try to fit your data in the most efficient way possible. That means for a timer that goes from 100 to 0 they will use a box that can hold just those values and nothing more. A data type is in essence the size and shape of that box.

Think of it like boxes in a warehouse. A `u8` is a small box that holds one byte, enough for values from 0 to 255. A `u16` is a medium box that holds two bytes. A `u32` is a big box that holds four bytes. The letter tells you what kind of box it is: "u" is unsigned (only positive numbers, like your health), "i" is signed (can go negative, like a temperature), "f" is floating point (has a decimal point, like a timer showing 4.5 seconds). The number is how many bits (8 bits = 1 byte, 16 bits = 2 bytes, 32 bits = 4 bytes).

If your health is 100 and never goes below 0, the programmer used a "u" box. If the timer shows decimal places like 4.5 seconds, they used an "f" box. If you are not sure what box they used, aggregated types like `"number"` scan every possible box size at once. Lumem does the digging, you just tell it what to look for.

| Type | Meaning | Like a... | Example value |
|------|---------|-----------|--------------|
| `"u8"` | unsigned 8-bit | tiny box | 0 to 255 |
| `"i32"` | signed 32-bit | medium signed box | -2 billion to 2 billion |
| `"f32"` | 32-bit float | decimal box | 3.14, 100.5 |
| `"str"` | text | a labeled drawer | "health", "Player_1" |
