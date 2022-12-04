local mmap_shm = require "mmap_shm"
local errors = require "errors"
local sleep = require "sleep"

local lock_hold_max_duration_seconds = 2
local loop_count = 10

local shm_name = "/somename"
local map_len = 4096

local op = arg[1]
local is_writer
local lock_name
if op == "unlink" then
    local err = mmap_shm.unlink(shm_name)
    if err ~= nil then
        print(err:error())
    end
    return
elseif op == "write" then
    is_writer = true
    lock_name = "wrlock"
elseif op == "read" then
    is_writer = false
    lock_name = "rdlock"
else
    print("Usage: luajit mmap_shm_ex1.lua (write|read|unlink")
    return
end

local ms, err = mmap_shm.open_or_create(shm_name, map_len)
if err ~= nil then
    print(err:error())
    return
end
if ms == nil then
    return errors.unreachable()
end

local lock = ms.rwlock
local i = 1
while i < loop_count do
    print(string.format("getting %s...", lock_name))
    local t1 = os.time()
    if is_writer then
        err = lock:wrlock()
        if err ~= nil then
            print(err:error())
            return
        end
    else
        err = lock:rdlock()
        if err ~= nil then
            print(err:error())
            return
        end
    end
    local t2 = os.time()
    print(string.format("got %s, elapsed %d seconds", lock_name, os.difftime(t2, t1)))

    local duration = lock_hold_max_duration_seconds * math.random()
    print(string.format("sleep for %f seconds...", duration))
    sleep(duration)

    err = lock:unlock()
    if err ~= nil then
        print(err:error())
        return
    end
    print("unlocked")

    i = i + 1
end
