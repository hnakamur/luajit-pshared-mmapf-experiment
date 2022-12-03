local ffi = require "ffi"
local file_mmap = require "file_mmap"

local filename = "a.dat"
local map_len = 4096
local m, err = file_mmap.Mmap:open(filename, map_len)
if m == nil then
	if err ~= nil then
		print(string.format("got err: %s", err:error()))
	end
	return
end
print(string.format("addr=%x", ffi.cast("uint64_t", m.addr)))

local n = #"hello japan"
ffi.copy(m.addr, "hello japan", n)
local data = ffi.string(m.addr, n)
print(string.format("a.lua data=\"%s\"", data))

local cmd = string.format("luajit b.lua %s %d", filename, map_len)
print(string.format("cmd=%s", cmd))
os.execute(cmd)
local data2 = ffi.string(m.addr, n)
print(string.format("a.lua data2=\"%s\"", data2))

err = m:close()
if err ~= nil then
	print(string.format("got err: %s", err:error()))
end
