local ffi = require "ffi"
local bit = require "bit"

local errors = require "errors"
local pshared_rwlock = require "pshared_rwlock"
local sleep = require "sleep"

ffi.cdef [[
    typedef uint32_t mode_t;
    typedef int64_t off_t;

    int shm_open(const char *name, int oflag, mode_t mode);
    int shm_unlink(const char *name);

    int close(int fd);
    int ftruncate(int fd, off_t length);
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

local function shm_open(name, flags, mode)
    local fd = ffi.C.shm_open(name, flags, mode)
    if fd == -1 then
        return nil, errors.new_errno { name = name, flags = flags, mode = mode }
    end
    return fd
end

local function shm_unlink(name)
    if ffi.C.shm_unlink(name) == -1 then
        return errors.new_errno { name = name }
    end
end

local function close(fd)
    if ffi.C.close(fd) == -1 then
        return errors.new_errno { fd = fd }
    end
end

local function ftruncate(fd, length)
    if ffi.C.ftruncate(fd, length) == -1 then
        return errors.new_errno { fd = fd }
    end
end

local function fchmod(fd, mode)
    if ffi.C.fchmod(fd, mode) == -1 then
        return errors.new_errno { fd = fd }
    end
end

local function mmap(addr, length, prot, flags, fd, offset)
    local maddr = ffi.cast("uint8_t *", ffi.C.mmap(addr, length, prot, flags, fd, offset))
    if maddr == nil then
        return nil, errors.new_errno()
    end
    return maddr
end

local function munmap(addr, length)
    if ffi.C.munmap(addr, length) == -1 then
        return errors.new_errno()
    end
end

local MmapShm = {}

function MmapShm:new(attrs)
    local o = attrs
    o.rwlock = pshared_rwlock.at(o.addr)
    setmetatable(o, self)
    self.__index = self
    return o
end

local function create(shm_name, map_len, rwlock_pref)
    local flags = bit.bor(O_RDWR, O_CREAT, O_EXCL)
    local fd, err = shm_open(shm_name, flags, S_IRUSR)
    if err ~= nil then
        return nil, err
    end

    local err_close_shm = function(err1)
        return err1:append(close(fd))
    end

    err = ftruncate(fd, map_len)
    if err ~= nil then
        return err_close_shm(err)
    end

    local addr
    addr, err = mmap(nil, map_len, bit.bor(PROT_READ, PROT_WRITE), MAP_SHARED, fd, 0)
    if err ~= nil then
        return err_close_shm(err)
    end

    local ms = MmapShm:new { fd = fd, addr = addr, shm_name = shm_name, map_len = map_len }

    local err_unmap_close_shm = function(err1)
        return err1:append(munmap(addr, map_len)):append(close(fd))
    end

    err = ms.rwlock:init(rwlock_pref)
    if err ~= nil then
        return err_unmap_close_shm(err)
    end

    err = fchmod(fd, bit.bor(S_IRUSR, S_IWUSR))
    if err ~= nil then
        return err_unmap_close_shm(err)
    end

    err = close(fd)
    if err ~= nil then
        return err:append(munmap(addr, map_len))
    end

    return ms
end

local function open(shm_name, map_len)
    local flags = bit.bor(O_RDWR)
    local fd, err = shm_open(shm_name, flags, bit.bor(S_IRUSR, S_IWUSR))
    if err ~= nil then
        return nil, err
    end

    local addr
    addr, err = mmap(nil, map_len, bit.bor(PROT_READ, PROT_WRITE), MAP_SHARED, fd, 0)
    if err ~= nil then
        return nil, err
    end

    err = close(fd)
    if err ~= nil then
        return nil, err
    end

    return MmapShm:new { fd = fd, addr = addr, shm_name = shm_name, map_len = map_len }
end

local wait_create_by_other_sec = 0.01 -- 10ms

local function open_or_create(shm_name, map_len, rwlock_pref)
    local f, err = open(shm_name, map_len)
    if err ~= nil then
        if err.errno ~= errors.ENOENT and err.errno ~= errors.EACCES then
            return nil, err
        end

        print(string.format("try creating MmapShm after open err=%s", err.errno == errors.ENOENT and "ENOENT" or "EACCES"))
        f, err = create(shm_name, map_len, rwlock_pref)
        if err ~= nil then
            if err.errno ~= errors.EEXIST then
                return nil, err
            end

            print("waiting for other process to create MmapShm")
            sleep(wait_create_by_other_sec)

            f, err = open(shm_name, map_len)
            if err ~= nil then
                return nil, err
            else
                print("opened MmapShm just created by other process")
            end
        else
            print("created MmapShm")
        end
    else
        print("opened MmapShm")
    end
    return f
end

local function unlink(name)
    return shm_unlink(name)
end

return {
    open_or_create = open_or_create,
    unlink = unlink,
}
