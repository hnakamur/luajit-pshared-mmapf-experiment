local errors = require "errors"

local err = errors.Error:new { code = 1, op = "open", path = "a.dat", hoge = nil }
print(err:error())
