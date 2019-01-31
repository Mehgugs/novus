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

function seed()
    local tm = gettime()
    local new = tm * ten6
    return (new - new%1)|0
end

randomseed(seed())

function shift(n, start1, stop1, start2, stop2)
    return (n - start1) / (stop1 - start1) * (stop2 - start2) + start2
end

function rand(A, B)
    return shift(random(), 0, 1, A, B)
end

function hash(str)
    local hash = 2166136261
    for i = 1, #str do
      hash = hash ~ str:byte(i)
      hash = (hash * 16777619) & 0xffffffff
    end
    return hash
end

function rid()
    return ("%x"):format(hash(tostring(seed())))
end

function reseed() randomseed(seed()) end

function isint(n)
    return n == (n - n%1)
end

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

function arity(f)
    local n = 0
    repeat n = n+1 until getlocal(f, n) == nil
    return n - 1
end

function _platform()
    local f = popen('uname')
    local res = f:read()
    if res == 'Darwin' then res = 'OSX' end
    f:close()
    return res
end

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

