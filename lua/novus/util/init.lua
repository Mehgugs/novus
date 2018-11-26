--import
local cqs = require"cqueues"
local cond = require"cqueues.condition"
local _lpeg = require"lpeg"
local Date = require"pl.Date"
local const = require"novus.const"

local gettime, sleep, me = cqs.monotime, cqs.sleep, cqs.running
local select = select
local insert, pack, unpack = table.insert, table.pack, table.unpack
local ipairs, pairs, next = ipairs, pairs, next
local random, randomseed, log = math.random, math.randomseed function math.randomseed() end
local floor, log = math.floor, math.log
local maxinteger = math.maxinteger
local string = string
local tostring, tonumber = tostring, tonumber
local getlocal, setlocal = debug.getlocal, debug.setlocal
local set,get = rawset,rawget
local getmetatable,setmetatable = getmetatable,setmetatable
local dsetmt = debug.setmetatable
local print = print
local type = type
local stderr = io.stderr 
local date, time, difftime, exit = os.date, os.time, os.difftime, os.exit
local P, Cc = _lpeg.P, _lpeg.Cc
--startmodule
local _ENV = {}

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

function funky()
    local fn_meta = {__metatable = false}

    function fn_meta:__band(g)
        if type(g) == 'function' then 
            return function(...) return g(self(...)) end 
        else return function(...) return self(g, ...) end
        end
    end

    function fn_meta:__shr(v)
        return self(v)
    end 

    function fn_meta.__shl(v, self)
        return self(v)
    end

    function fn_meta:__len() return arity(self) end

    dsetmt(print, fn_meta)
end

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

function weak() return setmetatable({}, {__mode = "k"}) end

local inheritance_cache = weak()

function get_inherit(t)
    local out = inheritance_cache[t]
    if out == nil then 
        out = {__index = t}
        inheritance_cache[t] = out
    end 
    return out 
end

function inherit(t)
    return setmetatable({}, get_inherit(t))
end

function namespace(parent) return inherit(parent) end



--misc

function rid()
    return ("%x"):format(hash(tostring(seed())))
end

getmetatable"".__mod = function(s, v)
    if type(v) == 'table' then return s:format(unpack(v))
    else return s:format(v)
    end
end

--lpeg utlity

lpeg = setmetatable(_lpeg.locale(), {__index = _lpeg})


function lpeg.exactly(n, p) 
    local patt = P(p)
    local out = patt
    for i = 1, n-1 do 
        out = out * patt
    end
    return out
end

function lpeg.just(p) return  P(p) * -1 end
local function truth() return true end
function lpeg.check(p) return  (P(p)/truth) + Cc(false) end 
function lpeg.sepby(s, p) p = P(p) return p * (s * p)^0 end
function lpeg.endby(s, p) p = P(p) return (p * s)^1 end
function lpeg.between(b, s) s = P(s) return  b * ((s * b)^1) end
function lpeg.anywhere (p)
    return P { p + 1 * _lpeg.V(1) }
end

function lpeg.some(p) return  P(p)^1 end
function lpeg.optionally(p) return  P(p)^-1 end
function lpeg.skip(p) return P(p)^0 end

local function swapper(a, b) return b, a end
function lpeg.swap(p) return p/swapper end
lpeg.many = skip

function lpeg.zipWith(f, ...) local p = f((...)) 
    for _, q in ipairs{select(2, ...)} do 
        p = p * f(q) 
    end
    return p
end

function lpeg.pairwise(t, fn)
    local p1, p2 = next(t)
    local a = fn(p1, p2)
    for k,v in next, t, p1 do 
        a = a * fn(k, v)
    end
    return a 
end

function lpeg.combine(t)
    local a = P(t[1]) 
    for i = 2, #t do 
        a = a * t[i]
    end
    return a
end

function lpeg.lazy(expr, cont)
    return P{cont + expr * _lpeg.V(1)}
end

function lpeg.callable(p)
    return function(...)
        return p:match(...)
    end 
end

--printing utility
local f = string.format

function parseHex(c)
    if c:sub(1,1) == '#' then c = c:sub(2) end
    if c:sub(1,2) == '0x' then c = c:sub(3) end
    local len = #c
    if not (len == 3 or len == 6) then 
        c = len > 6 and c:sub(1,6) or c .. ("0"):rep(6 - len)
    elseif len == 3 then 
        c = c:gsub("(.)", "%1%1")
    end
    local out = {}
    for i = 1,6,2 do 
        insert(out, tonumber(c:sub(i,i+1), 16))
    end
    return unpack(out, 1, 3)
end

local function color_code_to_seq(body)
    local r,g,b = body:match("(%d+),(%d+),(%d+)")
    if r and g and b then
        return ('\27[0m\27[38;2;%s;%s;%sm'):format(r,g,b)
    else
        r,g,b = parseHex(body)
        return r and g and b and ('\27[0m\27[38;2;%s;%s;%sm'):format(r,g,b) or ''
    end
end

local function highlight_code_to_seq(body)
    local body1, body2 = body:match("highlight:([^:]+):([^:]+)")
    local rb,gb,bb = parseHex(body1)
    local rf,gf,bf = parseHex(body2)
    return rb and gb and bb and rf and gf and bf and ('\27[0m\27[48;2;%s;%s;%sm\27[38;2;%s;%s;%sm'):format(rb,gb,bb,rf,gf,bf) or ''
end

function printf24(...)
    local str,n = f(...):gsub("($([^;]+);)", function(_, body) 
        if body == 'reset' then 
            return '\27[0m'
        elseif body:sub(1,9) == "highlight" then 
            return highlight_code_to_seq(body)
        else
            return color_code_to_seq(body)
        end
    end)
    return print(str .. (n > 0 and "\27[0m" or ""))
end

function info(...)
    return printf24("$highlight:#1a6:#000; %s INF $#1a6; %s", date"!%c", f(...))
end

function warn(...)
    return printf24("$highlight:#ef5:#000; %s WRN $#ef5; %s", date"!%c", f(...))
end

function error(...)
    return printf24("$highlight:#f14:#000; %s ERR $#f14; %s", date"!%c", f(...))
end

function fatal(...)
    error(...)
    error"Fatal error: quitting!"
    return exit(1)
end

colors = {
     info  = "#1a6"
    ,warn  = "#ef5"
    ,error = "#f14"
}

-- date

function pow(base, exp) -- +ve integer power mapping into [0,2^63-1]
    if exp == 0 then return 1 end
    if exp == 1 then return base end
    local result = 1;
    while(1)
    do
        if (exp & 1 ~= 0) then
            result = result * base
        end
        exp = exp >> 1;
        if (exp == 0) then
            break;
        end
        base = base * base;
    end
    return result;
end


function Date.fromMiliseconds(s)
    return Date(s / 1000)
end


local epochTerm = const.discord_epoch * 1000
function Date.fromSnowflake(id)
    local intflake = tonumber(id)
    if intflake > maxinteger then 
        warn("Snowflake %q is too big, parsed as float", id)
    end
    return Date.fromMiliseconds((intflake>>22) + epochTerm)
end

function Date:toISO()
	return date('!%FT%T', self.time) .. '+00:00'
end 

function Date.fromDateTableUTC(tbl)
    return Date(tbl, true)
end

local months = {
	Jan = 1, Feb = 2, Mar = 3, Apr = 4, May = 5, Jun = 6,
	Jul = 7, Aug = 8, Sep = 9, Oct = 10, Nov = 11, Dec = 12
}

function Date.fromHeader(str)
	local day, month, year, hour, min, sec = str:match(
		'%a+, (%d+) (%a+) (%d+) (%d+):(%d+):(%d+) GMT'
	)
	return Date.fromDateTableUTC {
		day = day, month = months[month], year = year,
		hour = hour, min = min, sec = sec, isdst = false,
	}
end

local function offset() 
    return difftime(time(), time(date('!*t')))
end

function Date.parseTableUTC(t)
    return time(t) + offset()
end

function Date.parseHeader(str)
	local day, month, year, hour, min, sec = str:match(
		'%a+, (%d+) (%a+) (%d+) (%d+):(%d+):(%d+) GMT'
	)
	return Date.parseTableUTC{
		day = day, month = months[month], year = year,
		hour = hour, min = min, sec = sec, isdst = false,
	}
end

Date = Date

--endmodule
return _ENV

