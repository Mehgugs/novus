--import
local cqs = require"cqueues"
local cond = require"cqueues.condition"

local require = require
local gettime, sleep, me = cqs.monotime, cqs.sleep, cqs.running
local select = select
local insert, unpack = table.insert, table.unpack
local ipairs, pairs = ipairs, pairs
local random, randomseed, log = math.random, math.randomseed function math.randomseed() end
local floor, log = math.floor, math.log
local maxinteger = math.maxinteger
local string = string
local tostring, tonumber = tostring, tonumber
local getlocal, setlocal = debug.getlocal, debug.setlocal
local set,get = rawset,rawget
local getmetatable,setmetatable = getmetatable,setmetatable
local type = type
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

--function utilities

function compose(a, b)
    return function(...) return b(a(...)) end 
end

function bind(f, a) 
    return function(...)
        return f(a, ...)
    end
end 

local function bindmanyworker(f, n, a, ...)
    if n > 0 then return bindmanyworker(bind(f, a), n - 1, ...)
    else return f 
    end 
end

function bindmany(f, ...)
    return bindmanyworker(f, select('#', ...), ...)
end

call = bind(bind, bindmany)

--list utilities

function map(f, l, ...)
    local out = {}
    for k, v in pairs(l) do 
        out[k] = f(v, ...)
    end
    return out 
end

function filter(f, l, ...)
    local out = {}
    for _, v in ipairs(l) do 
        if f (v, ...) then insert(out, v) end
    end 
    return out
end 

function zip(f, l1, l2) 
    local out = {}
    for k, v in ipairs(l1) do 
        out[k] = f(v, l2[k])
    end
    return out
end

function fold(f, a, l, ...)
    for _, v in ipairs(l) do 
        a = f(a, v, ...)
    end
    return a
end

function find(f, l)
    for k, v in pairs(l) do 
        if f(v, k) then return k, v end 
    end
end

function each(f, l)
    for k,v in ipairs(l) do 
        f(v, k)
    end
end

function reverse(l)
    local out = {}
    for i = #l, 1, -1 do 
        insert(out, l[i]) 
    end 
    return out
end

function shuffle(l)
    local new = {}
    for i = 1, #l do 
        local j = random(i)
        if j ~= i then 
            new[i] = new[j]
        end
        new[j] = l[i]
    end
    return new
end

--vararg transformers

local function vmapn(n, f, a, ...) 
    if n > 0 then return f(a), vmapn(n -1, f,...) end
end

function vmap(f, ...) return vmapn(select('#', ...), f, ...) end

local function vfoldn(n, f, a, i, ...)
    if n > 0 then return vfoldn(n -1, f, f(a, i), ...) else return a end
end

function vfold(f, a, ...) return vfoldn(select('#', ...), f, a, ...) end

local function chopper(acc, i)
    table.insert(acc.tail, acc.last)
    acc.len = acc.len + 1
    acc.last = i
    return acc 
end

function vchop(first, ...)
    local result = vfold(chopper, {last = first, tail = {}, len = 0}, ...)
    return result.last, unpack(result.tail, 1, result.len)
end

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

-- simple mutex implementation

local mutex_behaviour = {}

mutex_behaviour.__index = mutex_behaviour

function mutex_behaviour:lock(timeout)
    if self.inuse then 
        self.inuse = self.cond:wait(timeout)
    else 
        self.inuse = true 
    end 
end

function mutex_behaviour:unlock()
    if self.inuse then 
        self.inuse = false 
        self.cond:signal(1)
    end
end

local function unlockAfter(self, time) 
    sleep(time)
    self:unlock()
end

function mutex_behaviour:unlockAfter(time)
    me():wrap(unlockAfter, self, time)
end

function mutex()
    return setmetatable({
         cond = cond.new()
        ,inuse= false
    }, mutex_behaviour)
end

--environment & metaprogramming

function getlastlocal(at)
    local current;
    local currentv;
    local count = 1
    while true do 
        local next, val = debug.getlocal(at + 1, count)
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
        local next, val = debug.getlocal(at+1, count)
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

--misc

function weak() return setmetatable({}, {__mode = "k"}) end

function rid()
    return ("%x"):format(hash(tostring(seed())))
end

getmetatable"".__mod = function(s, v)
    if type(v) == 'table' then return s:format(unpack(v))
    else return s:format(v)
    end
end

function _platform()
    local f = popen('uname')
    local res = f:read()
    if res == 'Darwin' then res = 'OSX' end
    f:close()
    return res
end

platform = _platform()

--more general table utils

function mergewith(A, B)
    for k,v in pairs(B) do 
        A[k] = v 
    end
    return A
end

function merge(...)
    return vfold(mergewith, {}, ...)
end

function overwrite(...) return vfold(mergewith, ...) end

function default(v) return setmetatable({}, {__index = function() return v end}) end

function reflect(t)
    local new = {}
    for k, v in pairs(t) do 
        new[k] = v 
        new[v] = k
    end
    return new
end

function module(s) return (loader(s)) end 

-- merge in special cases
overwrite(
     _ENV
    ,require"novus.util.printf"
    ,require"novus.util.date"
)

--endmodule
return _ENV

