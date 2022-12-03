local ffi = require "ffi"
local errors = require "errors"

ffi.cdef [[
	typedef struct pthread_mutex_t {
		union {
			char __size[40];
			long int __align;
		};
	} pthread_mutex_t;

	typedef struct pthread_mutexattr_t {
		union {
			char __size[4];
			int __align;
		};
	} pthread_mutexattr_t;

    int pthread_mutexattr_init(pthread_mutexattr_t *a);
    int pthread_mutexattr_destroy(pthread_mutexattr_t *a);
    enum {
        PTHREAD_MUTEX_STALLED,
        PTHREAD_MUTEX_ROBUST,
    };
    int pthread_mutexattr_setrobust(pthread_mutexattr_t *attr, int robust);  
    enum {
        PTHREAD_PROCESS_PRIVATE,
        PTHREAD_PROCESS_SHARED
    };
    int pthread_mutexattr_setpshared(pthread_mutexattr_t *attr, int pshared);

    int pthread_mutex_init(pthread_mutex_t *m, const pthread_mutexattr_t *a);
    int pthread_mutex_destroy(pthread_mutex_t *m);
    int pthread_mutex_lock(pthread_mutex_t *m);
    int pthread_mutex_unlock(pthread_mutex_t *m);
]]

local function err_from_rc(rc)
    if rc ~= 0 then
        return errors.new { errno = rc }
    end
end

local function mutexattr_init(a)
    return err_from_rc(ffi.C.pthread_mutexattr_init(a))
end

local function mutexattr_destroy(a)
    return err_from_rc(ffi.C.pthread_mutexattr_destroy(a))
end

local function mutexattr_setrobust(a, robust)
    return err_from_rc(ffi.C.pthread_mutexattr_setrobust(a, robust))
end

local function mutexattr_setpshared(a, robust)
    return err_from_rc(ffi.C.pthread_mutexattr_setpshared(a, robust))
end

local Mutex = {}

function Mutex:new_at(addr)
    local inner = ffi.cast("pthread_mutex_t *", addr)
    local o = { inner = inner }
    setmetatable(o, self)
    self.__index = self
    return o
end

function Mutex:init()
    ffi.C.pthread_mutex_init(self.inner)
end

function Mutex:init_pshared()
    print(string.format("Mutex:init_pshared start, inner=%x", ffi.cast("uint64_t", self.inner)))
    local attr = ffi.new("pthread_mutexattr_t[1]")
    local err = mutexattr_init(attr[0])
    if err ~= nil then
        return err
    end
    print("after mutexattr_init")
    err = mutexattr_setrobust(attr[0], ffi.C.PTHREAD_MUTEX_ROBUST)
    if err ~= nil then
        return err
    end
    print("after mutexattr_setrobust")
    err = mutexattr_setpshared(attr[0], ffi.C.PTHREAD_PROCESS_SHARED)
    if err ~= nil then
        return err
    end
    print("after mutexattr_setpshared")

    ffi.C.pthread_mutex_init(self.inner, attr[0])
    print("after pthread_mutex_init")

    return mutexattr_destroy(attr[0])
end

function Mutex:lock()
    local rc = ffi.C.pthread_mutex_lock(self.inner)
    if rc ~= 0 then
        return errors.new { errno = rc, op = "pthread_mutex_lock" }
    end
end

function Mutex:unlock()
    local rc = ffi.C.pthread_mutex_unlock(self.inner)
    if rc ~= 0 then
        return errors.new { errno = rc, op = "pthread_mutex_unlock" }
    end
end

function Mutex:destroy()
    local rc = ffi.C.pthread_mutex_destroy(self.inner)
    if rc ~= 0 then
        return errors.new { errno = rc, op = "pthread_mutex_destroy" }
    end
end

local function mutex_at(addr)
    return Mutex:new_at(addr)
end

local function new_mutex()
    local inner = ffi.new("pthread_mutex_t[1]")
    return mutex_at(inner[0])
end

local function new_mutex_pshared()
    local inner = ffi.new("pthread_mutex_t[1]")
    local mu = mutex_at(inner[0])
    local err = mu:init_pshared()
    if err ~= nil then
        return nil, err
    end
    return mu
end

return {
    new_mutex = new_mutex,
    new_mutex_pshared = new_mutex_pshared,
    mutex_at = mutex_at,
}
