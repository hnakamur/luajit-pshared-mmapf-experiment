local pshared_mmapf = require "pshared_mmapf"
local errors = require "errors"
local sleep = require "sleep"

local mapf, err = pshared_mmapf.open("b.dat", 4096)
print(string.format("mapf=%s, err=%s", mapf, err))
if err ~= nil then
    print(err:error())
    return
end
if mapf == nil then
    return errors.new { desc = "unreachable" }
end

local mu = mapf.mutex
print(string.format("mu=%s", mu))
if arg[1] ~= nil then
    print("before mu:init_pshared")
    mu:init_pshared()

    local ffi = require "ffi"
    print(string.format("mu.inner=%x, mapf.addr=%x", ffi.cast("uint64_t", mu.inner), ffi.cast("uint64_t", mapf.addr)))

    print("initialized mutex")
end

print("before lock")
err = mu:lock()
if err ~= nil then
    print(err:error())
    return
end
print("locked")

sleep(3)

err = mu:unlock()
if err ~= nil then
    print(err:error())
    return
end
print("unlocked")

err = mapf:close()
if err ~= nil then
    print(err:error())
    return
end
