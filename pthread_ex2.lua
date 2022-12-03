local pthread = require "pthread"
local sleep = require "sleep"
local file_mmap = require "file_mmap"

local filename = "a.dat"
local map_len = 4096
local m, err = file_mmap.Mmap:open(filename, map_len)
if m == nil then
	if err ~= nil then
		print(err:error())
	end
	return
end

local mu = pthread.mutex_at(m.addr)
if arg[1] ~= nil then
    mu:init_pshared()
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

err = m:close()
if err ~= nil then
    print(err:error())
end
