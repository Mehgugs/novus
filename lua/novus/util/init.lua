--- Utilities.
-- @module novus.util
-- @alias _ENV

--import
require"novus.util.string".inject()
local cqs = require"cqueues"
local tableutils = require"novus.util.table"
local require = require
local gettime = cqs.monotime
local random, randomseed = math.random, math.randomseed function math.randomseed() end
local tostring = tostring
local getlocal = debug.getlocal
local setmetatable = setmetatable
local pcall = pcall
local popen = io.popen
local loader = package.searchers[2]

--startmodule
local _ENV = setmetatable({}, {__index = function(self, k)
    local path = ('novus.util.%s'):format(k)
    local ok, M = pcall(require, path)
    if ok then
        self.info("novus.util loaded module $white;%s$info; which was found @ $white;%q$info;.", k, path)
        self[k] = M
        return M
    end
end})

--general utilities

local ten6 = 10^6|0

--- Generates a seed based on `cqueues.monotime` (an alternative to os.time as a seed).
-- @treturn number The seed.
function seed()
    local tm = gettime()
    local new = tm * ten6
    return (new - new%1)|0
end

randomseed(seed())

--- Takes a value `n` in the range `start1`, `stop1` (inclusive) and converts it into a value
-- in the range `start2`, `stop2`.
-- @tparam number n The input value.
-- @tparam number start1 The start of the range the value `n` is in.
-- @tparam number stop1 The end of the range.
-- @tparam number start2 The start of the new range.
-- @tparam number stop2 The end of the new range.
-- @treturn number The new value in the range [`start2`, `stop2`]
function shift(n, start1, stop1, start2, stop2)
    return (n - start1) / (stop1 - start1) * (stop2 - start2) + start2
end

--- Returns a random double between [`A`, `B`].
-- @tparam number A
-- @tparam number B
-- @treturn number The random number.
function rand(A, B)
    return shift(random(), 0, 1, A, B)
end

--- Computes the FNV-1a 32-bit hash of the given string.
-- @tparam string str The string to hash.
-- @treturn number The numeric hash.
function hash(str)
    local hash = 2166136261
    for i = 1, #str do
      hash = hash ~ str:byte(i)
      hash = (hash * 16777619) & 0xffffffff
    end
    return hash
end

--- Returns a random identifier string
-- @treturn string The random id.
function rid()
    return ("%x"):format(hash(tostring(seed())))
end

--- Reseeds lua's random number generator.
function reseed() randomseed(seed()) end

function isint(n)
    return n == (n - n%1)
end

--- Gets the last proper local declared at the given stack level, 1 is the current scope.
-- @tparam number at The stack level to look at.
-- @treturn string The local's name.
-- @return The local's value.
-- @treturn number The index of the local.
function getlastlocal(at)
    local current;
    local currentv;
    local count = 1
    while true do
        local next, val = getlocal(at + 1, count)
        if next ~= nil and next:sub(1,1) ~= "(" then
            count = count + 1
            current = next
            currentv = val
        elseif next == nil or next:sub(1,1) == "(" then
            return current, currentv, count-1
        end
    end
end

--- Attempts to locate a localized _ENV at the given stack level.
-- @tparam number at The stack level to look at.
-- @treturn[1] table The _ENV table for the stack level.
-- @treturn[2] nil Nil if nothing is found.
local function getnamespace(at)
    at=at or 0
    local count=1
    repeat
        local next, val = getlocal(at+1, count)
        if next=='_ENV' then
            return val
        end
        count = count+1
    until next == nil
end

---Computes the arity of a function, which is the number of named parameters it has.
-- @tparam function f The function to compute.
-- @treturn number The arity.
function arity(f)
    local n = 0
    repeat n = n+1 until getlocal(f, n) == nil
    return n - 1
end

local function _platform()
    local f = popen('uname')
    local res = f:read()
    if res == 'Darwin' then res = 'OSX' end
    f:close()
    return res
end

--- The operating system platform
platform = _platform()

function module(s) return (loader(s)) end

-- merge in special cases
tableutils.overwrite(
     _ENV
    ,tableutils
    ,require"novus.util.printf"
    ,require"novus.util.date"
    ,require"novus.util.list"
    ,require"novus.util.func"
)

--endmodule
return _ENV

