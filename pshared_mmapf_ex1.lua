local pshared_mmapf = require "pshared_mmapf"
local pthread = require "pthread"
local errors = require "errors"
local sleep = require "sleep"

local filename = "b.dat"
local map_len = 4096

if arg[1] == "init" then
    print("creating file")
    local mapf, err = pshared_mmapf.create(filename, map_len)
    if err ~= nil then
        print(err:error())
        return
    end
    if mapf == nil then
        return errors.unreachable()
    end

    err = mapf:close()
    if err ~= nil then
        print(err:error())
        return
    end

    print("mutex_size=", pthread.mutex_size())
    print("created file and initialized mutex, exiting")
    return
end

local mapf, err = pshared_mmapf.open(filename, map_len)
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
