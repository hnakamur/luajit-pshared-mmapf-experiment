local errors = require "errors"

local err = errors.Error:new { errno = 1, detail = "open file" }
print(err:error())

local errs = errors.join(err,
    errors.Error:new { errno = 2, detail = "close file",
        child = errors.Error:new { errno = 3, op = "some operation", path = "\"program files/foo\"" } })
if errs ~= nil then
    print(string.format("errs=%s", errs:error()))
else
    print("errs is nil")
    return
end

errs:append(errors.Error:new { errno = 4, op = "another operation", path = "b.dat" } )
print(string.format("errs after append=%s", errs:error()))

local errs2 = errors.join(errors.Error:new { errno = 2, detail = "close file" }, nil)
if errs2 ~= nil then
    print(string.format("errs2=%s", errs2:error()))
else
    print("errs2 is nil")
    return
end

local errs3 = errors.join(nil, errors.Error:new { errno = 2, detail = "close file" })
if errs3 ~= nil then
    print(string.format("errs3=%s", errs3:error()))
else
    print("errs3 is nil")
    return
end

local errs4 = errors.join(nil, nil)
if errs4 ~= nil then
    print(string.format("errs4=%s", errs4:error()))
else
    print("errs4 is nil")
end
