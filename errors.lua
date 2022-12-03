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
    return string.format("{errno=%d, detail=\"%s\"}", self.errno, self.detail)
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
    join = join,
}
