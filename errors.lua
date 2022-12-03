local ffi = require "ffi"
local cjson = require "cjson"

local Error = {}

function Error:new(attrs)
    local o = attrs
    setmetatable(o, self)
    self.__index = self
    return o
end

function Error:error()
    return cjson.encode(self)
end

-- new creates an Error instance.
-- NOTE: attrs will be modified.
local function new(attrs)
    attrs = attrs or {}
    if attrs.traceback == nil then
        attrs.traceback = debug.traceback()
    end
    return Error:new(attrs)
end

ffi.cdef [[
    char *strerror(int errnum);
]]

local function strerror(errnum)
    return ffi.string(ffi.C.strerror(errnum))
end

-- new_errno creates an Error instance.
-- attrs.errno and attrs.desc will be set automatically if not set.
-- NOTE: attrs will be modified.
local function new_errno(attrs)
    attrs = attrs or {}
    if attrs.errno == nil then
        attrs.errno = ffi.errno()
    end
    if attrs.desc == nil then
        attrs.desc = strerror(attrs.errno)
    end
    return new(attrs)
end

-- MultiErrors extends Error and contains multiple Error instances.
local MultiErrors = Error:new {}

function MultiErrors:new(errs)
    local o = errs
    setmetatable(o, self)
    self.__index = self
    return o
end

function MultiErrors:append(errno_obj)
    if errno_obj ~= nil then
        table.insert(self, errno_obj)
    end
end

-- join returns a MultiErrors if both errno_obj1 and errno_obj2 is non-nil,
-- or errno_obj1 if errno_obj1 is non-nil, or errno_obj2 otherwise.
--
-- NOTE: Idealy arguments would be errno_objects, an array obj errno_obj,
-- but ipairs stops at nil element and does not iterate after nil,
-- so we take two arguments as errno_obj1 and errno_obj2
local function join(errno_obj1, errno_obj2)
    if errno_obj1 ~= nil then
        if errno_obj2 ~= nil then
            return MultiErrors:new { errno_obj1, errno_obj2 }
        end
        return errno_obj1
    end
    return errno_obj2
end

function Error:append(err)
    return join(self, err)
end

local function unreachable()
    return new { desc = "unreachable" }
end

return {
    new       = new,
    new_errno = new_errno,
    unreachable = unreachable,
    join      = join,

    EPERM     = 1, -- Operation not permitted
    ENOENT    = 2, -- No such file or directory
    ESRCH     = 3, -- No such process
    EINTR     = 4, -- Interrupted system call
    EIO       = 5, -- I/O error
    ENXIO     = 6, -- No such device or address
    E2BIG     = 7, -- Argument list too long
    ENOEXEC   = 8, -- Exec format error
    EBADF     = 9, -- Bad file number
    ECHILD    = 10, -- No child processes
    EAGAIN    = 11, -- Try again
    ENOMEM    = 12, -- Out of memory
    EACCES    = 13, -- Permission denied
    EFAULT    = 14, -- Bad address
    ENOTBLK   = 15, -- Block device required
    EBUSY     = 16, -- Device or resource busy
    EEXIST    = 17, -- File exists
    EXDEV     = 18, -- Cross-device link
    ENODEV    = 19, -- No such device
    ENOTDIR   = 20, -- Not a directory
    EISDIR    = 21, -- Is a directory
    EINVAL    = 22, -- Invalid argument
    ENFILE    = 23, -- File table overflow
    EMFILE    = 24, -- Too many open files
    ENOTTY    = 25, -- Not a typewriter
    ETXTBSY   = 26, -- Text file busy
    EFBIG     = 27, -- File too large
    ENOSPC    = 28, -- No space left on device
    ESPIPE    = 29, -- Illegal seek
    EROFS     = 30, -- Read-only file system
    EMLINK    = 31, -- Too many links
    EPIPE     = 32, -- Broken pipe
    EDOM      = 33, -- Math argument out of domain of func
    ERAN      = 34, -- Math result not representable
}
