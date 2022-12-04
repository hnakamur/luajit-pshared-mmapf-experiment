local pshared_mmapf = require "pshared_mmapf"
local errors = require "errors"
local sleep = require "sleep"

local write_ratio = 0.1
local lock_hold_max_duration_seconds = 2
local loop_count = 10

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

local err_close_mmapf = function(err1)
    local err2 = mapf:close()
    if err2 ~= nil then
        local err3 = errors.join(err1, err2)
        print(err3:error())
        return
    end
end

local lock = mapf.rwlock
local i = 1
while i < loop_count do
    if math.random() < write_ratio then
        print("before wrlock")
        err = lock:wrlock()
        if err ~= nil then
            err_close_mmapf(err)
            return
        end
        print("got wrlock")
    else
        print("before rdlock")
        err = lock:rdlock()
        if err ~= nil then
            err_close_mmapf(err)
            return
        end
        print("got rdlock")
    end

    local duration = lock_hold_max_duration_seconds * math.random()
    print(string.format("sleep for %f seconds", duration))
    sleep(duration)

    err = lock:unlock()
    if err ~= nil then
        err_close_mmapf(err)
        return
    end
    print("unlocked")

    i = i + 1
end

err = mapf:close()
if err ~= nil then
    print(err:error())
    return
end
