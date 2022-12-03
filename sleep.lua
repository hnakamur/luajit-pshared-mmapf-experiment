local ffi = require "ffi"
local errors = require "errors"

ffi.cdef [[
    typedef uint64_t time_t;

    struct timespec {
        time_t tv_sec;        /* seconds */
        long   tv_nsec;       /* nanoseconds */
    };

    int nanosleep(const struct timespec *req, struct timespec *rem);
]]

-- sleep sleeps for specified seconds.
-- seconds can have the fractional part (ex. 0.1)
local function sleep(seconds)
    local req = ffi.new("struct timespec[1]")
    local sec, frac = math.modf(seconds)
    req[0].tv_sec = sec
    req[0].tv_nsec = frac * 1000000000
    if ffi.C.nanosleep(req, nil) == -1 then
        return errors.new_errno
    end
end

return sleep
