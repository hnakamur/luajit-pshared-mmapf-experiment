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

local function mutexattr_setpshared(a, pshared)
    return err_from_rc(ffi.C.pthread_mutexattr_setpshared(a, pshared))
end

local metatable = {}
metatable.__index = metatable

function metatable:init()
    local attr = ffi.new("pthread_mutexattr_t[1]")
    local err = mutexattr_init(attr[0])
    if err ~= nil then
        return err
    end

    err = mutexattr_setrobust(attr[0], ffi.C.PTHREAD_MUTEX_ROBUST)
    if err ~= nil then
        return err
    end

    err = mutexattr_setpshared(attr[0], ffi.C.PTHREAD_PROCESS_SHARED)
    if err ~= nil then
        return err
    end

    ffi.C.pthread_mutex_init(self, attr[0])
    return mutexattr_destroy(attr[0])
end

function metatable:lock()
    return err_from_rc(ffi.C.pthread_mutex_lock(self))
end

function metatable:unlock()
    return err_from_rc(ffi.C.pthread_mutex_unlock(self))
end

function metatable:destroy()
    return err_from_rc(ffi.C.pthread_mutex_destroy(self))
end

ffi.metatype('pthread_mutex_t', metatable)

local function at(addr)
    return ffi.cast("pthread_mutex_t *", addr)
end

local function size()
    return ffi.sizeof("pthread_mutex_t")
end

return {
    at = at,
    size = size,
}
