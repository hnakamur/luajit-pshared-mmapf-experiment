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

return {
    new = new,
    new_errno = new_errno,
    join = join,
}
