--- Lpeg combinators and utilities.
-- @module util.lpeg
-- @alias _ENV

--imports--
local _lpeg = require"lpeglabel"
local setmetatable = setmetatable
local P, Cc, V, Cs, C, Ct = _lpeg.P, _lpeg.Cc, _lpeg.V, _lpeg.Cs, _lpeg.C, _lpeg.Ct
local ipairs, next = ipairs, next
local select = select
--start-module--
local _ENV = setmetatable(_lpeg.locale(), {__index = _lpeg})

--- Returns an Lpeg pattern which matches exactly n times.
-- @tparam number n The number of times to match.
-- @tparam lpeg-pattern p
-- @treturn lpeg-pattern The final pattern.
function exactly(n, p)
    local patt = P(p)
    local out = patt
    for _ = 1, n-1 do
        out = out * patt
    end
    return out
end

--- Returns an Lpeg pattern which matches just the input pattern or nothing.
-- @tparam lpeg-pattern p
-- @treturn lpeg-pattern The final pattern.
function just(p) return  P(p) * -1 end

local function truth() return true end

--- Returns an Lpeg pattern which captures `true` when it matches or `false` otherwise.
-- @tparam lpeg-pattern p
-- @treturn lpeg-pattern The final pattern.
function check(p) return  (P(p)/truth) + Cc(false) end

--- Returns a pattern which matches one or more of: the input pattern
--  separated by the pattern `s`.
-- @tparam lpeg-pattern s
-- @tparam lpeg-pattern p
-- @treturn lpeg-pattern The final pattern.
function sepby(s, p) p = P(p) return p * (s * p)^0 end

--- Returns a pattern which matches one or more of: the input pattern
--  followed by the pattern `s`.
-- @tparam lpeg-pattern s
-- @tparam lpeg-pattern p
-- @treturn lpeg-pattern The final pattern.
function endby(s, p) p = P(p) return (p * s)^1 end

--- Returns a pattern which matches zero or more of the input pattern,
--  between the pattern `s`.
-- @tparam lpeg-pattern b The input pattern.
-- @tparam lpeg-pattern s
-- @treturn lpeg-pattern The final pattern.
function between(b, s) s = P(s) return  b * ((s * b)^1) end

--- Returns a pattern which matches the input pattern anywhere in the string.
-- @tparam lpeg-pattern p
-- @treturn lpeg-pattern The final pattern.
function anywhere (p)
    return P { p + 1 * V(1) }
end

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

function gsub (s, patt, repl)
    patt = P(patt)
    patt = Cs((patt / repl + 1)^0)
    return patt:match(s)
end

function split (s, sep)
    sep = P(sep)
    local elem = C((1 - sep)^0)
    local p = Ct(elem * (sep * elem)^0)
    return p:match(s)
end

--end-module--
return _ENV