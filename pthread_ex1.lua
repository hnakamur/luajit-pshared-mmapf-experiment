local pthread = require "pthread"
local sleep = require "sleep"

local mu = pthread.new_mutex()

local err = mu:lock()
if err ~= nil then
    print(err:error())
    return
end
print("locked")

sleep(0.5)

err = mu:unlock()
if err ~= nil then
    print(err:error())
    return
end
print("unlocked")

err = mu:destroy()
if err ~= nil then
    print(err:error())
    return
end

