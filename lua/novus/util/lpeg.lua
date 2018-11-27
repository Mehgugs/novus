--imports--
local _lpeg = require"lpeg"
local setmetatable = setmetatable
local P, Cc, V = _lpeg.P, _lpeg.Cc, _lpeg.V
local ipairs, next = ipairs, next
local select = select
--start-module--
local _ENV = setmetatable(_lpeg.locale(), {__index = _lpeg})

function exactly(n, p) 
    local patt = P(p)
    local out = patt
    for i = 1, n-1 do 
        out = out * patt
    end
    return out
end

function just(p) return  P(p) * -1 end

local function truth() return true end
function check(p) return  (P(p)/truth) + Cc(false) end 

function sepby(s, p) p = P(p) return p * (s * p)^0 end
function endby(s, p) p = P(p) return (p * s)^1 end
function between(b, s) s = P(s) return  b * ((s * b)^1) end
function anywhere (p)
    return P { p + 1 * V(1) }
end

function some(p) return  P(p)^1 end
function optionally(p) return  P(p)^-1 end


local function swapper(a, b) return b, a end
function swap(p) return p/swapper end

function zipWith(f, ...) local p = f((...)) 
    for _, q in ipairs{select(2, ...)} do 
        p = p * f(q) 
    end
    return p
end

function pairwise(t, fn)
    local p1, p2 = next(t)
    local a = fn(p1, p2)
    for k,v in next, t, p1 do 
        a = a * fn(k, v)
    end
    return a 
end

function combine(t)
    local a = P(t[1]) 
    for i = 2, #t do 
        a = a * t[i]
    end
    return a
end

function lazy(expr, cont)
    return P{cont + expr * _lpeg.V(1)}
end

function callable(p)
    return function(...)
        return p:match(...)
    end 
end

-- some useful patterns
patterns = {}

patterns.token = S"MN" * exactly(58, R("09", "az", "AZ") + "-" + "_" + ".") 
	
--end-module--
return _ENV