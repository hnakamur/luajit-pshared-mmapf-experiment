local pshared_mmapf = require "pshared_mmapf"
local sleep = require "sleep"

local mapf, err = pshared_mmapf.open("b.dat", 4096)
if mapf == nil then
    if err ~= nil then
        print(err:error())
        return
    end
end

local mu = mapf.mutex
if arg[1] ~= nil then
    mu:init_pshared()
    print("initialized mutex")
end

print("before lock")
err = mu:lock()
if err ~= nil then
    print(err:error())
    return
end
print("locked")

sleep(3)

err = mu:unlock()
if err ~= nil then
    print(err:error())
    return
end
print("unlocked")

err = mapf:close()
if err ~= nil then
    print(err:error())
    return
end
