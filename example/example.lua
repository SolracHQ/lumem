local pid = 121233
local address = 0x7ffcd98025e8

local value = lumem:get(pid, address, "u32")
print("value: " .. value)

lumem:set(pid, address, "u32", 33)
print("value at address after write: " .. lumem:get(pid, address, "u32"))