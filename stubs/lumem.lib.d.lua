---@meta lumem

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

---@class Entry
-- A typed memory value at a fixed address.
local Entry = {}

---@class EntryList
---@operator len: integer
---@operator add: EntryList
-- A collection of Entry objects returned by memory scans.
local EntryList = {}

---@class Region
-- A mapped memory region with address bounds, permissions, and pathname.
local Region = {}

---@class RegionList
---@operator len: integer
-- A collection of Region objects returned by process:regions().
local RegionList = {}

---@class Process
-- A system process with metadata and memory scanning capabilities.
local Process = {}

---@class ProcList
---@operator len: integer
-- A collection of Process objects returned by lumem:scan().
local ProcList = {}

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

-- Creates a typed Entry at a process memory address for reading and writing.
---@param config EntryConfig # Table with pid, address, type, and optional size for str.
---@return Entry
function Lumem:entry(config) end

-- Returns the size of this region in bytes.
---@return integer
function Region:get_size() end

-- Returns the mapped file pathname, or empty string if anonymous.
---@return string
function Region:get_pathname() end

-- Returns the memory permissions at this entry's address.
---@return Permissions
function Entry:get_perms() end

-- Returns the group ID of the process, or nil if unavailable.
---@return integer?
function Process:get_gid() end

-- Unpins this entry. The value will no longer be kept at the pinned amount.
function Entry:unpin() end

-- Returns the permission flags of this region.
---@return Permissions
function Region:get_perms() end

-- Keeps only entries matching a selector, removing the rest.
---@param selector Selector # Comparison predicate table.
function EntryList:filter(selector) end

-- Returns the end address of this region.
---@return integer
function Region:get_end() end

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

-- Returns the inode of the mapped file, or 0 if anonymous.
---@return integer
function Region:get_inode() end

-- Pins this entry so its value stays at the written amount.
---@param value any? # Optional value. Defaults to current cached value.
function Entry:pin(value) end

-- Returns the full command line with null separators replaced by spaces.
---@return string
function Process:get_cmd_line() end

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

-- Returns the process ID.
---@return integer
function Process:get_pid() end

-- Returns the element at the given 1-based index.
---@param index integer # 1-based index.
---@return Region?
function RegionList:get(index) end

-- Writes a new value to this entry's address in the target process.
---@param value any # Value to write.
function Entry:set(value) end

-- Returns an iterator compatible with Lua for..in syntax.
---@return function
---@return userdata
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

-- Returns a Process for the current process. No root needed, useful when loaded via require("lumem").
---@return Process
function Lumem:self() end

-- Returns the parent process ID, or nil if unavailable.
---@return integer?
function Process:get_parent_pid() end

-- Returns the user ID that owns the process, or nil if unavailable.
---@return integer?
function Process:get_uid() end

-- Returns the start address of this region.
---@return integer
function Region:get_start() end

-- Unpins every entry in the list.
function EntryList:unpin() end

-- Returns an iterator compatible with Lua for..in syntax.
---@return function
---@return userdata
---@return integer?
function EntryList:iter() end

-- Scans live processes and returns a ProcList matching the optional filter.
---@param filter Filter? # Optional filter with pid, uid, name, or cmdLine fields.
---@return ProcList
function Lumem:scan(filter) end

-- Returns a new list with the same entries.
---@return EntryList
function EntryList:clone() end

-- Returns the file offset of this region.
---@return integer
function Region:get_offset() end

-- Pins every entry in the list so their values stay at the written amount.
---@param value any? # Optional value to pin. Defaults to each entry's current cached value.
function EntryList:pin(value) end

-- Returns the memory regions for this process, optionally filtered by permissions.
---@param filter Permissions? # Optional permission filter string ("rwxp") or table of names.
---@return RegionList
function Process:regions(filter) end

-- Returns the process name.
---@return string
function Process:get_name() end

-- Returns the element at the given 1-based index.
---@param index integer # 1-based index.
---@return Process?
function ProcList:get(index) end

-- Returns an iterator compatible with Lua for..in syntax.
---@return function
---@return userdata
---@return integer?
function ProcList:iter() end

return Lumem