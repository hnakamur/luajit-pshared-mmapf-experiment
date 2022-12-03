local ffi = require "ffi"
local bit = require "bit"

local errors = require "errors"
local pthread = require "pthread"
local sleep = require "sleep"

ffi.cdef [[
    typedef uint32_t mode_t;

    int open(const char *pathname, int flags, mode_t mode);
    int close(int fd);
    ssize_t write(int fd, const void *buf, size_t count);
    int fchmod(int fd, mode_t mode);

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

local c = {}

function c.open(pathname, flags, mode)
    local fd = ffi.C.open(pathname, flags, mode)
    if fd == -1 then
        return nil, errors.new_errno { pathanme = pathname, flags = flags, mode = mode }
    end
    return fd
end

function c.close(fd)
    if ffi.C.close(fd) == -1 then
        return errors.new_errno { fd = fd }
    end
end

function c.fchmod(fd, mode)
    if ffi.C.fchmod(fd, mode) == -1 then
        return errors.new_errno { fd = fd, mode = mode }
    end
end

function c.write(fd, buf, count)
    local n = ffi.C.write(fd, buf, count)
    if n == -1 then
        return nil, errors.new_errno { fd = fd }
    end
    return n
end

function c.mmap(addr, length, prot, flags, fd, offset)
    local maddr = ffi.cast("uint8_t *", ffi.C.mmap(addr, length, prot, flags, fd, offset))
    if maddr == nil then
        return nil, errors.new_errno()
    end
    return maddr
end

function c.munmap(addr, length)
    if ffi.C.munmap(addr, length) == -1 then
        return errors.new_errno()
    end
end

local Mmap = {}

function Mmap:new(attrs)
    local o = attrs
    setmetatable(o, self)
    self.__index = self
    return o
end

local open_max_retries = 3
local open_retry_interval_seconds = 0.01 -- 10ms

local function init_write_mutex(fd)
    local mu, err = pthread.new_mutex_pshared()
    if err ~= nil then
        return err
    end
    if mu == nil then
        return errors.new { desc = "unreachable" }
    end

    local _n
    _n, err = c.write(fd, mu.inner, ffi.sizeof(mu.inner))
    if err ~= nil then
        return err
    end

    err = c.fchmod(fd, bit.bor(S_IRUSR, S_IWUSR))
    if err ~= nil then
        return err
    end
end

local function open(filename, map_len)
    local created, fd, err
    local i = 1
    while i <= open_max_retries do
        created = false
        local flags = bit.bor(O_RDWR, O_CLOEXEC, O_SYNC)
        fd, err = c.open(filename, flags, S_IRUSR)
        if err ~= nil then
            return nil, err
            -- print(string.format("open err i=%d, errno=%d", i, err.errno))
            -- if err.errno ~= errors.ENOENT then
            --     return nil, err
            -- end

            -- local j = 1
            -- while j <= open_max_retries do
            --     -- print(string.format("retrying open, j=%d", j))
            --     flags = bit.bor(flags, O_CREAT, O_EXCL)
            --     -- print(string.format("befre retry open, flags=%x", flags))
            --     fd, err = c.open(filename, flags, S_IRUSR)
            --     if err ~= nil then
            --         print(string.format("open err j=%d, errno=%d", j, err.errno))
            --         if err.errno ~= errors.EEXIST then
            --             return nil, err
            --         end

            --         sleep(open_retry_interval_seconds)
            --         j = j + 1
            --     else
            --         created = true
            --         print("created file for mmap")

            --         err = init_write_mutex(fd)
            --         if err ~= nil then
            --             return nil, err
            --         end

            --         err = c.close(fd)
            --         if err ~= nil then
            --             return nil, err
            --         end

            --         break
            --     end
            -- end

            -- i = i + 1
        else
            break
        end
    end
    if err ~= nil then
        return nil, err
    end

    print(string.format("fd=%d", fd))
    local addr
    addr, err = c.mmap(nil, map_len, bit.bor(PROT_READ, PROT_WRITE), MAP_SHARED, fd, 0)
    if err ~= nil then
        local err2 = c.close(fd)
        if err2 ~= nil then
            err2.filename = filename
        end
        return nil, errors.join(err, err2)
    end

    local mu = pthread.mutex_at(addr)
    print(string.format("mu=%p, addr=%x", mu, ffi.cast("uint64_t", addr)))
    local m = Mmap:new { fd = fd, addr = addr, filename = filename, map_len = map_len, mutex = mu, }

    -- if created then
    --     mu:init_pshared()
    --     err = c.fchmod(fd, bit.bor(S_IRUSR, S_IWUSR))
    --     if err ~= nil then
    --         local err2 = m:close()
    --         return errors.join(err, err2)
    --     end
    -- end

    return m
end

function Mmap:close()
    local err = c.munmap(self.addr, self.map_len)
    local err2 = c.close(self.fd)
    if err2 ~= nil then
        err2.filename = self.filename
    end
    return errors.join(err, err2)
end

return {
    open = open,
}
