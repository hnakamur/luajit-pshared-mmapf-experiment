local ffi = require "ffi"
local bit = require "bit"

local errors = require "errors"
local pshared_mutex = require "pshared_mutex"
local sleep = require "sleep"

ffi.cdef [[
    typedef uint32_t mode_t;
    typedef int64_t off_t;

    int open(const char *pathname, int flags, mode_t mode);
    int close(int fd);
    int ftruncate(int fd, off_t length);
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

function c.ftruncate(fd, length)
    if ffi.C.ftruncate(fd, length) == -1 then
        return errors.new_errno { fd = fd }
    end
end

function c.fchmod(fd, mode)
    if ffi.C.fchmod(fd, mode) == -1 then
        return errors.new_errno { fd = fd }
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
    o.mutex = pshared_mutex.at(o.addr)
    setmetatable(o, self)
    self.__index = self
    return o
end

local function create(filename, map_len)
    local flags = bit.bor(O_RDWR, O_CREAT, O_EXCL, O_CLOEXEC, O_SYNC)
    local fd, err = c.open(filename, flags, S_IRUSR)
    if err ~= nil then
        return nil, err
    end

    local err_close_fd = function(err1)
        local err2 = c.close(fd)
        if err2 ~= nil then
            err2.filename = filename
        end
        return nil, errors.join(err1, err2)
    end

    err = c.ftruncate(fd, map_len)
    if err ~= nil then
        return err_close_fd(err)
    end

    local addr
    addr, err = c.mmap(nil, map_len, bit.bor(PROT_READ, PROT_WRITE), MAP_SHARED, fd, 0)
    if err ~= nil then
        return err_close_fd(err)
    end

    local m = Mmap:new { fd = fd, addr = addr, filename = filename, map_len = map_len }

    local err_close_m = function(err1)
        local err2 = m:close(fd)
        if err2 ~= nil then
            err2.filename = filename
        end
        return nil, errors.join(err1, err2)
    end

    err = m.mutex:init()
    if err ~= nil then
        return err_close_m(err)
    end

    err = c.fchmod(fd, bit.bor(S_IRUSR, S_IWUSR))
    if err ~= nil then
        return nil, err
    end

    return m
end

local function open(filename, map_len)
    local flags = bit.bor(O_RDWR, O_CLOEXEC, O_SYNC)
    local fd, err = c.open(filename, flags, bit.bor(S_IRUSR, S_IWUSR))
    if err ~= nil then
        return nil, err
    end

    local addr
    addr, err = c.mmap(nil, map_len, bit.bor(PROT_READ, PROT_WRITE), MAP_SHARED, fd, 0)
    if err ~= nil then
        local err2 = c.close(fd)
        if err2 ~= nil then
            err2.filename = filename
        end
        return nil, errors.join(err, err2)
    end

    return Mmap:new { fd = fd, addr = addr, filename = filename, map_len = map_len }
end

local wait_create_by_other_sec = 0.01 -- 10ms

local function open_or_create(filename, map_len)
    local f, err = open(filename, map_len)
    if err ~= nil then
        if err.errno ~= errors.ENOENT and err.errno ~= errors.EPERM then
            return nil, err
        end

        print("try creating file")
        f, err = create(filename, map_len)
        if err ~= nil then
            if err.errno ~= errors.EEXIST then
                return nil, err
            end

            print("waiting for other process to create file")
            sleep(wait_create_by_other_sec)

            f, err = open(filename, map_len)
            if err ~= nil then
                return nil, err
            else
                print("opened file just created by other process")
            end
        else
            print("created file")
        end
    else
        print("opened file")
    end
    return f
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
    create = create,
    open = open,
    open_or_create = open_or_create,
}
