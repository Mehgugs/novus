--imports--
local ult, mtoint, mntype, max_int = math.ult, math.tointeger, math.type, math.maxinteger
local setmetatable = setmetatable
local type = type
local time = os.time
local lpeg = require"novus.util.lpeg"
local const = require"novus.const"
--start-module--
local _ENV = setmetatable({}, {__call = function(self,s) return self.touint(s) end})

local function by10(n, i) i = i or 1
    for _ = 1, i do n = (n << 4) - (n << 2) - (n << 1) end
    return n
end


local function to_integer_worker(s) -- string -> uint64
    local n = 0
    local l = #s
    for i = l -1,0, -1  do
        n = n + by10(s:sub(i+1,i+1)|0, l-i-1)
    end
    return n
end

local two_63 = 2^63
local two_64 = 2^64

local function float_to_uint(f)
    if f > max_int then
        return mtoint(((f + two_63) % two_64) - two_63)
    else
        return mtoint(f)
    end
end

local function lnum_to_uint(l)
    if mntype(l) == 'integer' then
        return l
    else
        return float_to_uint(l)
    end
end

local numeral = lpeg.digit^1 * -1
function touint(s)
    if type(s) == 'number' then return lnum_to_uint(s)
    elseif type(s) == 'string' and numeral:match(s) then
        return to_integer_worker(s)
    end
end

function tostring(i) return ("%u"):format(i) end

local function udiv (n, d)
    if d < 0 then
      if ult(n, d) then return 0
      else return 1
      end
    end
    local q = ((n >> 1) // d) << 1
    local r = n - q * d
    if not ult(r, d) then q = q + 1 end
    return q
end

local epoch = const.discord_epoch * 1000

function timestamp(s)
    return udiv((touint(s) >> 22) + epoch , 1000)
end

function fromtime(s)
    s = by10(s or time(), 3)
    return (s - epoch) << 22
end
local inc = -1
function synthesize(s, worker, pid)
    inc = (inc + 1) &  0xFFF
    worker = ((worker or 0) & 63) << 17
    pid = ((pid or 0) & 63) << 12
    return fromtime(s) | worker | pid | inc
end
--sort two snowflake objects
function snowflake_sort(i,j) return ult(touint(i.id) , touint(j.id)) end

--sort two snowflake ids
function id_sort(i,j) return ult(touint(i) , touint(j)) end

--end-module--
return _ENV