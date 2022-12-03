local ffi = require "ffi"

ffi.cdef [[
    char *strerror(int errnum);
]]

local function strerror(errnum)
    return ffi.string(ffi.C.strerror(errnum))
end

local Errno = {
    errno = 0,
    detail = "",
}

function Errno:new(errno, detail)
    local o = { errno = errno, detail = detail }
    setmetatable(o, self)
    self.__index = self
    return o
end

function Errno:error()
    return string.format("{errno=%d, desc=%s, detail=\"%s\"}", self.errno, strerror(self.errno), self.detail)
end

local MultiErrors = {
    errs = {}
}

function MultiErrors:new(errs)
    local o = { errs = errs }
    setmetatable(o, self)
    self.__index = self
    return o
end

function MultiErrors:append(errno_obj)
    if errno_obj ~= nil then
        table.insert(self.errs, errno_obj)
    end
end

function MultiErrors:error()
    local msgs = {}
    for i, err in ipairs(self.errs) do
        msgs[i] = err:error()
    end
    return table.concat(msgs, ", ")
end

local function new_errno(detail)
    return Errno:new(ffi.errno(), detail)
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
    Errno = Errno,
    new_errno = new_errno,
    join = join,
}
