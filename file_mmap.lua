local ffi = require "ffi"
local bit = require "bit"

local errors = require "errors"

ffi.cdef [[
    int open(const char *pathname, int flags);
    int close(int fd);

    void *mmap(void *addr, size_t length, int prot, int flags, int fd, int64_t offset);
    int munmap(void *addr, size_t length);
]]

-- See /usr/include/asm-generic/fcntl.h
local O_RDWR = 0x2
local O_CREAT = 0x40
local O_EXCL = 0x80
local O_SYNC = 0x1000
local O_CLOEXEC = 0x80000

-- See /usr/include/linux/stat.h
local S_IWUSR = 0x80
local S_IRUSR = 0x100

-- See /usr/include/x86_64-linux-gnu/bits/mman-linux.h
local PROT_READ  = 0x01 -- pages can be read
local PROT_WRITE = 0x02 -- pages can be written

-- See /usr/include/x86_64-linux-gnu/bits/mman-linux.h
local MAP_SHARED = 0x01 -- share changes

local Mmap = {}

local function close(fd, filename)
    if ffi.C.close(fd) == -1 then
        return errors.new_errno { op = "close", filename = filename }
    end
    return nil
end

function Mmap:open(filename, map_len)
    local fd = ffi.C.open(filename, bit.bor(O_RDWR, O_SYNC))
    if fd == -1 then
        return nil, errors.new_errno { op = "open", filename = filename }
    end

    local addr = ffi.cast("uint8_t *", ffi.C.mmap(nil, map_len, bit.bor(PROT_READ, PROT_WRITE), MAP_SHARED, fd, 0))
    if addr == nil then
        local err = errors.new_errno { op = "mmap", filename = filename }
        local err2 = close(fd, filename)
        return nil, errors.join(err, err2)
    end

    local o = {
        filename = filename,
        map_len = map_len,
        fd = fd,
        addr = addr,
    }
    setmetatable(o, self)
    self.__index = self
    return o
end

function Mmap:close()
    local err
    if ffi.C.munmap(self.addr, self.map_len) == -1 then
        err = errors.new_errno { op = "munmap", filename = self.filename }
    end

    local err2 = close(self.fd, self.filename)
    return errors.join(err, err2)
end

return {
    Mmap = Mmap,
}
