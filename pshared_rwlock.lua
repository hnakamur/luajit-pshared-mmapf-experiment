local ffi = require "ffi"
local errors = require "errors"

ffi.cdef [[
	typedef struct pthread_rwlock_t {
		union {
			char __size[56];
			long int __align;
		};
	} pthread_rwlock_t;

	typedef struct pthread_rwlockattr_t {
		union {
			char __size[8];
			long int __align;
		};
	} pthread_rwlockattr_t;

    int pthread_rwlockattr_init(pthread_rwlockattr_t *a);
    int pthread_rwlockattr_destroy(pthread_rwlockattr_t *a);
    enum {
        PTHREAD_PROCESS_PRIVATE,
        PTHREAD_PROCESS_SHARED
    };
    int pthread_rwlockattr_setpshared(pthread_rwlockattr_t *attr, int pshared);

    int pthread_rwlock_init(pthread_rwlock_t *l, const pthread_rwlockattr_t *attr);
    int pthread_rwlock_destroy(pthread_rwlock_t *l);
    int pthread_rwlock_wrlock(pthread_rwlock_t *l);
    int pthread_rwlock_rdlock(pthread_rwlock_t *l);
    int pthread_rwlock_trywrlock(pthread_rwlock_t *l);
    int pthread_rwlock_tryrdlock(pthread_rwlock_t *l);
    int pthread_rwlock_unlock(pthread_rwlock_t *l);
]]

local function err_from_rc(rc)
    if rc ~= 0 then
        return errors.new { errno = rc }
    end
end

local function rwlockattr_init(a)
    return err_from_rc(ffi.C.pthread_rwlockattr_init(a))
end

local function rwlockattr_destroy(a)
    return err_from_rc(ffi.C.pthread_rwlockattr_destroy(a))
end

local function rwlockattr_setpshared(a, pshared)
    return err_from_rc(ffi.C.pthread_rwlockattr_setpshared(a, pshared))
end

local metatable = {}
metatable.__index = metatable

function metatable:init()
    local attr = ffi.new("pthread_rwlockattr_t[1]")
    local err = rwlockattr_init(attr[0])
    if err ~= nil then
        return err
    end

    err = rwlockattr_setpshared(attr[0], ffi.C.PTHREAD_PROCESS_SHARED)
    if err ~= nil then
        return err
    end

    ffi.C.pthread_rwlock_init(self, attr[0])
    return rwlockattr_destroy(attr[0])
end

function metatable:wrlock()
    return err_from_rc(ffi.C.pthread_rwlock_wrlock(self))
end

function metatable:rdlock()
    return err_from_rc(ffi.C.pthread_rwlock_rdlock(self))
end

function metatable:trywrlock()
    return err_from_rc(ffi.C.pthread_rwlock_trywrlock(self))
end

function metatable:tryrdlock()
    return err_from_rc(ffi.C.pthread_rwlock_tryrdlock(self))
end

function metatable:unlock()
    return err_from_rc(ffi.C.pthread_rwlock_unlock(self))
end

function metatable:destroy()
    return err_from_rc(ffi.C.pthread_rwlock_destroy(self))
end

ffi.metatype('pthread_rwlock_t', metatable)

local function at(addr)
    return ffi.cast("pthread_rwlock_t *", addr)
end

local function size()
    return ffi.sizeof("pthread_rwlock_t")
end

return {
    at = at,
    size = size,
}
