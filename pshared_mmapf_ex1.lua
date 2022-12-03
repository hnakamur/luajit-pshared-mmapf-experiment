local pshared_mmapf = require "pshared_mmapf"
local errors = require "errors"
local sleep = require "sleep"

if arg[1] ~= nil then
    local wait = tonumber(arg[1])
    if wait ~= nil then
        sleep(wait)
    end
end

local filename = "b.dat"
local map_len = 4096
local mapf, err = pshared_mmapf.open_or_create(filename, map_len)
if err ~= nil then
    print(err:error())
    return
end
if mapf == nil then
    return errors.unreachable()
end

local mu = mapf.mutex
print("before lock")
err = mu:lock()
if err ~= nil then
    print(err:error())
    return
end
print("locked")

sleep(1)

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
