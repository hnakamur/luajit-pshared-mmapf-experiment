local ffi = require "ffi"
local file_mmap = require "file_mmap"

local filename = arg[1]
local map_len = tonumber(arg[2], 10)

local m, err = file_mmap.Mmap:open(filename, map_len)
if m == nil then
	if err ~= nil then
		print(string.format("got err: %s", err:error()))
	end
	return
end
print(string.format("b.lua addr=%x", ffi.cast("uint64_t", m.addr)))

local data = ffi.string(m.addr, #"hello japan")
print(string.format("b.lua data=\"%s\"", data))
ffi.copy(m.addr + 6, "world", 5)

err = m:close()
if err ~= nil then
	print(string.format("got err: %s", err:error()))
end
