local errors = require "errors"

local err = errors.Errno:new(1, "open file")
print(err:error())

local errs = errors.join(err, errors.Errno:new(2, "close file"))
if errs ~= nil then
    print(string.format("errs=%s", errs:error()))
else
    print("errs is nil")
end

local errs2 = errors.join(errors.Errno:new(2, "close file"), nil)
if errs2 ~= nil then
    print(string.format("errs2=%s", errs2:error()))
else
    print("errs2 is nil")
end

local errs3 = errors.join(nil, errors.Errno:new(2, "close file"))
if errs3 ~= nil then
    print(string.format("errs3=%s", errs3:error()))
else
    print("errs3 is nil")
end

local errs4 = errors.join(nil, nil)
if errs4 ~= nil then
    print(string.format("errs4=%s", errs4:error()))
else
    print("errs4 is nil")
end
