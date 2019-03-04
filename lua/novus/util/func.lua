--- Function utilities.
-- @module util.func
-- @alias _ENV

--imports--
local select = select
local insert = table.insert
local unpack = table.unpack
--start-module--
local _ENV = {}

--- composes two functions. `compose(f,g) = g(f(...))`.
-- @tparam function a The inner function.
-- @tparam function b The outer function.
-- @treturn function The resulting function.
function compose(a, b)
    return function(...) return b(a(...)) end
end

--- binds a single value into the first argument of given function.
-- @tparam function f The function to bind onto.
-- @param a The value to bind.
-- @treturn function The new function.
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

--- Like @{bind} but accepts many arguments, binding each onto the Nth argument of `f`.
-- @tparam function f The function to bind onto.
-- @param ... One or more values to bind.
function bindmany(f, ...)
    return bindmanyworker(f, select('#', ...), ...)
end

--- Creates a factory function from the given function.
-- @function call
-- @usage
--   newprint = call(print)
--   myprint = newprint("Magicks says:")
--   myprint("Hello, world!") --> Magicks says:   Hello, world!
-- @tparam function f The function to create a factory from.
-- @treturn function The factory function.
call = bind(bind, bindmany)

function eq(A, B) return A == B end
function not_eq(A, B) return A ~= B end
--vararg transformers

local function vmapn(n, f, a, ...)
    if n > 0 then return f(a), vmapn(n -1, f,...) end
end

--- Performs a map over a vararg, returning a new vararg.
-- @tparam function f The mapping function.
-- @param ... The vararg of values.
-- @return The new vararg where each member i is f(i).
function vmap(f, ...) return vmapn(select('#', ...), f, ...) end

local function vfoldn(n, f, a, i, ...)
    if n > 0 then return vfoldn(n -1, f, f(a, i), ...) else return a end
end

--- Performs a lefthanded reduction over a vararg, returning a value.
-- @tparam function f The reducer.
-- @param a The inital value of the accumulator.
-- @param ... The vararg of values.
-- @return The accumulated value.
function vfold(f, a, ...) return vfoldn(select('#', ...), f, a, ...) end

local function chopper(acc, i)
    insert(acc.tail, acc.last)
    acc.len = acc.len + 1
    acc.last = i
    return acc
end

--- Chops the last value off a vararg, and retuns it and the resulting vararg.
--- You should call this function with a vararg `vchop(...)`.
-- @param first The first vararg value.
-- @param ... The rest of the vararg.
-- @return The last value of the vararg.
-- @return The vararg with the last value removed.
function vchop(first, ...)
    local result = vfold(chopper, {last = first, tail = {}, len = 0}, ...)
    return result.last, unpack(result.tail, 1, result.len)
end
--end-module--
return _ENV