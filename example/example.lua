-- Find the target process by name
local procs = lumem:scan("target")

if #procs == 0 then
    print("target not running -- start ./target in another terminal first")
    return
end

-- procs[1] will also works but LSP prefers get(1) since __index is opaque
local p = procs:get(1)
assert(p ~= nil, "failed to get process")

-- Process objects have a rich tostring display
print(p)

-- List writable memory regions
local regions = p:regions()
print(regions)

-- Initial scan: health starts at 100
local entries = regions:scan("u32", { range = { 0, 100 } })
print(string.format("\ninitial scan: %d match(es) for value 0-100", #entries))

-- Narrow down by tracking decrements over time
for round = 1, 4 do
    print(string.format("\nround %d/4: waiting for value to decrease...", round))
    os.execute("sleep 2")

    entries:filter({ change = "decrease" })
    print(string.format("  %d match(es) remaining", #entries))

    if #entries == 0 then
        print("  narrowed to zero -- restart with a broader initial scan")
        break
    end

    if #entries <= 3 then
        print(entries)
    end
end

-- Pin 150 to whatever survived the narrowing
if #entries > 0 then
    print(string.format("\nwriting 150 to %d location(s)", #entries))
    entries:pin(150)

    local e = entries:get(1)
    assert(e ~= nil, "failed to get entry")
    print(string.format("verified: 0x%x = %s", e:get_address(), tostring(e:get())))
    print("the target terminal should now show health: 150")
    print("press enter to finish (pin keeps the value alive until then)...")
    io.read()
    entries:unpin()
end
