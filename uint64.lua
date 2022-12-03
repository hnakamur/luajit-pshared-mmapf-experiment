local ffi = require "ffi"

local uint64_union_t = ffi.typeof [[
  union {
    struct { uint32_t lo; uint32_t hi; };
    uint64_t x;
  }
]]

local function split(x)
    local m = uint64_union_t()
    m.x = x
    return m.hi, m.lo
end

local function join(hi, lo)
    local m = uint64_union_t()
    m.hi, m.lo = hi, lo
    return m.x
end

return {
    split = split,
    join = join,
}
