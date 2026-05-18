---@meta _

---@class Permissions
---@field bits integer
-- A bitfield of memory region permission flags.
local Permissions = {}

---@class EntryConfig
---@field pid integer # Target process ID.
---@field address integer # Memory address.
---@field type DataType # Data type string ("u8", "i32", "str", etc.).
---@field size integer? # Required for str type. Buffer size in bytes.
-- Configuration for lumem:entry().
local EntryConfig = {}

-- A typed memory value at a fixed address.
---@class Entry
-- A typed memory value at a fixed address.
local Entry = {}

-- A collection of Entry objects returned by memory scans.
---@class EntryList
---@operator len(EntryList): integer
---@operator add(EntryList): EntryList # Merges two entry lists into a new one.
-- A collection of Entry objects returned by memory scans.
local EntryList = {}

-- A mapped memory region with address bounds, permissions, and pathname.
---@class Region
-- A mapped memory region with address bounds, permissions, and pathname.
local Region = {}

-- A collection of Region objects returned by process:regions().
---@class RegionList
---@operator len(RegionList): integer
-- A collection of Region objects returned by process:regions().
local RegionList = {}

-- A system process with metadata and memory scanning capabilities.
---@class Process
-- A system process with metadata and memory scanning capabilities.
local Process = {}

-- A collection of Process objects returned by lumem:scan().
---@class ProcList
---@operator len(ProcList): integer
-- A collection of Process objects returned by lumem:scan().
local ProcList = {}

-- The root scripting object for process memory inspection. Provides scan, entry, and self.
---@class Lumem
-- The root scripting object for process memory inspection. Provides scan, entry, and self.
local Lumem = {}

-- A scalar or family type for memory operations.
---@alias DataType
---| 'u8' # 8-bit unsigned integer
---| 'u16' # 16-bit unsigned integer
---| 'u32' # 32-bit unsigned integer
---| 'u64' # 64-bit unsigned integer
---| 'i8' # 8-bit signed integer
---| 'i16' # 16-bit signed integer
---| 'i32' # 32-bit signed integer
---| 'i64' # 64-bit signed integer
---| 'f32' # 32-bit float
---| 'f64' # 64-bit float
---| 'number' # any numeric type
---| 'integer' # any integer type
---| 'signed' # any signed integer type
---| 'int' # any signed integer type
---| 'unsigned' # any unsigned integer type
---| 'uint' # any unsigned integer type
---| 'float' # any float type

-- Describes how a value changed since the last scan.
---@alias ChangeType
---| 'increase'
---| 'decrease'
---| 'none'
---| 'any'

-- A comparison predicate for filtering memory scan results.
---@alias Selector
---| number # Shorthand for { eq = x }.
---| string # Shorthand for { eq = s }.
---| function # Shorthand for { custom = f }.
---| { eq: any } # Equal to the given value.
---| { gt: any } # Greater than the given value.
---| { lt: any } # Less than the given value.
---| { ge: any } # Greater than or equal to the given value.
---| { le: any } # Less than or equal to the given value.
---| { ne: any } # Not equal to the given value.
---| { range: any[] } # Inclusive range as { lo, hi }.
---| { needle: string, context: number?, bounds: number[]? } # Find bytes with optional padding. context is symmetric, bounds is { left, right }.
---| { delimited: { prefix: string?, suffix: string?, len: number } } # Match a window anchored by prefix/suffix boundaries.
---| { needle: string, ... } # Shorthand for { contains = { needle, ... } }.
---| { prefix: string?, suffix: string?, len: number } # Shorthand for { delimited = { prefix, suffix, len } }.
---| { change: ChangeType } # Change type: increase, decrease, none, any.
---| { custom: function } # Custom Lua function(value, prev_value) returning bool.

-- Process filter criteria. Accepts a table with optional fields, or a string (shorthand for { name = s }).
---@alias Filter
---| string # Shorthand for { name = s }.
---| { pid: integer?, uid: integer?, name: string?, cmdLine: string? } # Table of filter criteria.

-- Returns the element at the given 1-based index.
---@param index integer # 1-based index.
---@return Process?
function ProcList:get(index) end

-- Returns the size of this region in bytes.
---@return integer
function Region:get_size() end

-- Returns an iterator compatible with Lua for..in syntax.
---@return function
---@return ProcList
---@return integer?
function ProcList:iter() end

-- Returns the memory permissions at this entry's address.
---@return Permissions
function Entry:get_perms() end

---@param arg1 ProcList
function ProcList.__gc(arg1) end

-- Creates a typed Entry at a process memory address for reading and writing.
---@param config EntryConfig # Table with pid, address, type, and optional size for str.
---@return Entry
function Lumem:entry(config) end

-- Unpins this entry. The value will no longer be kept at the pinned amount.
function Entry:unpin() end

---@param arg1 Permissions
---@return string
function Permissions.__tostring(arg1) end

-- Keeps only entries matching a selector, removing the rest.
---@param selector Selector # Comparison predicate table.
function EntryList:filter(selector) end

---@param arg1 Process
function Process.__gc(arg1) end

---@param arg1 ProcList
---@param arg2 integer
---@return Process?
function ProcList.__index(arg1, arg2) end

-- Keeps only processes matching the given criteria, removing the rest.
---@param filter Filter # Filter with pid, uid, name, or cmdLine fields.
function ProcList:filter(filter) end

-- Scans all regions in the list for matching memory values.
---@param dataType DataType # Data type to scan for.
---@param selector Selector # Comparison predicate table.
---@return EntryList
function RegionList:scan(dataType, selector) end

-- Returns a new list with the same processes.
---@return ProcList
function ProcList:clone() end

-- Pins this entry so its value stays at the written amount.
---@param value any? # Optional value. Defaults to current cached value.
function Entry:pin(value) end

---@param arg1 EntryList
---@param arg2 integer
---@return Entry?
function EntryList.__index(arg1, arg2) end

---@param arg1 RegionList
---@param arg2 integer
---@return Region?
function RegionList.__index(arg1, arg2) end

-- Returns the element at the given 1-based index.
---@param index integer # 1-based index.
---@return Entry?
function EntryList:get(index) end

-- Re-reads the entry's value from process memory and returns it.
---@return any
function Entry:get() end

-- Returns the memory address of this entry.
---@return integer
function Entry:get_address() end

-- Writes a value to every entry in the list.
---@param value any # Value to write to each entry's address.
function EntryList:set(value) end

-- Scans all processes in the list for matching memory values.
---@param dataType DataType # Data type to scan for.
---@param selector Selector # Comparison predicate table.
---@param filter Permissions? # Optional permission filter.
---@return EntryList
function ProcList:scan(dataType, selector, filter) end

-- Returns the element at the given 1-based index.
---@param index integer # 1-based index.
---@return Region?
function RegionList:get(index) end

---@param arg1 Region
function Region.__gc(arg1) end

---@param arg1 Entry
function Entry.__gc(arg1) end

-- Writes a new value to this entry's address in the target process.
---@param value any # Value to write.
function Entry:set(value) end

-- Returns an iterator compatible with Lua for..in syntax.
---@return function
---@return RegionList
---@return integer?
function RegionList:iter() end

-- Returns the PID of the process this entry belongs to.
---@return integer
function Entry:get_pid() end

-- Returns a new list with the same regions.
---@return RegionList
function RegionList:clone() end

-- Scans the process memory for values matching the data type and selector.
---@param dataType DataType # Data type to scan for ("u8", "i32", "f64", etc.).
---@param selector Selector # Comparison predicate table.
---@param filter Permissions? # Optional permission filter.
---@return EntryList
function Process:scan(dataType, selector, filter) end

-- Scans this region for memory values matching the data type and selector.
---@param dataType DataType # Data type to scan for.
---@param selector Selector # Comparison predicate table.
---@return EntryList
function Region:scan(dataType, selector) end

---@param arg1 Region
---@return string
function Region.__tostring(arg1) end

---@param arg1 EntryList
function EntryList.__gc(arg1) end

-- Returns a Process for the current process. No root needed, useful when loaded via require("lumem").
---@return Process
function Lumem:self() end

---@param arg1 RegionList
---@return string
function RegionList.__tostring(arg1) end

---@param arg1 ProcList
---@return string
function ProcList.__tostring(arg1) end

-- Unpins every entry in the list.
function EntryList:unpin() end

---@param arg1 Process
---@return string
function Process.__tostring(arg1) end

-- Returns an iterator compatible with Lua for..in syntax.
---@return function
---@return EntryList
---@return integer?
function EntryList:iter() end

-- Scans live processes and returns a ProcList matching the optional filter.
---@param filter Filter? # Optional filter with pid, uid, name, or cmdLine fields.
---@return ProcList
function Lumem:scan(filter) end

---@param arg1 Lumem
---@return string
function Lumem.__tostring(arg1) end

-- Returns a new list with the same entries.
---@return EntryList
function EntryList:clone() end

-- Pins every entry in the list so their values stay at the written amount.
---@param value any? # Optional value to pin. Defaults to each entry's current cached value.
function EntryList:pin(value) end

-- Returns the memory regions for this process, optionally filtered by permissions.
---@param filter Permissions? # Optional permission filter string ("rwxp") or table of names.
---@return RegionList
function Process:regions(filter) end

---@param arg1 EntryList
---@return string
function EntryList.__tostring(arg1) end

---@param arg1 Entry
---@return string
function Entry.__tostring(arg1) end

---@param arg1 RegionList
function RegionList.__gc(arg1) end

lumem = Lumem