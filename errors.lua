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

ffi.cdef [[
    char *strerror(int errnum);
]]

local function strerror(errnum)
    return ffi.string(ffi.C.strerror(errnum))
end

local function new_errno(attrs)
    if attrs.errno == nil then
        attrs.errno = ffi.errno()
    end
    if attrs.desc == nil then
        attrs.desc = strerror(attrs.errno)
    end
    return Error:new(attrs)
end

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
    Error = Error,
    new_errno = new_errno,
    join = join,
}
