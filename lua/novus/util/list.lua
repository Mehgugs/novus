--- List utilities
-- @module util.list
-- @alias _ENV

--imports--
local ipairs,pairs = ipairs, pairs
local insert = table.insert
local random = math.random
--start-module--
local _ENV = {}

--- Apply a function to all elements of a list, creating a new table of the results.
-- @tparam function f The mapping function.
-- @tparam table l The list.
-- @param[opt] ... Extra arguments to the mapping function `f`.
-- @treturn table The list of results.
-- @usage
--  list.map(function(x) return 2*x end, {1, 2, 3}) --> {2, 4, 6}
function map(f, l, ...)
    local out = {}
    for k, v in pairs(l) do
        out[k] = f(v, ...)
    end
    return out
end

--- Apply a function to all elements of a list, if the function
--  returns a truthy value the element is added to the new list.
-- @tparam function f The predicate function.
-- @tparam table l The list.
-- @param[opt] ... Extra arguments to the predicate function `f`.
-- @treturn table The filtered list
-- @usage
--  list.filter(
--       function(x) return x % 2 == 0 end,
--      {0, 1, 2, 3, 4, 5}
--  ) --> {0, 2, 4}
function filter(f, l, ...)
    local out = {}
    for _, v in ipairs(l) do
        if f (v, ...) then insert(out, v) end
    end
    return out
end

--- Zips together two lists, calling the function argument
-- on each pair of the list elements to produce the new value.
-- @tparam function f The zipping function.
-- @tparam table l1 The first list.
-- @tparam table l2 The second list.
-- @treturn table The resulting list.
-- @usage
--  l1, l2 = {1, 2, 3}, {5, 10, 15}
--  list.zip(
--      function(a, b) return a * b end,
--      l1, l2
--  ) --> {5, 20, 45}
function zip(f, l1, l2)
    local out = {}
    for k, v in ipairs(l1) do
        out[k] = f(v, l2[k])
    end
    return out
end

--- Performs a lefthanded reduction over a list, returning a value.
-- @tparam function f The reducer.
-- @param a The initial value of the accumulator.
-- @tparam table l The list.
-- @param[opt] ... Extra values to the reducer `f`.
-- @return The accumulated value.
-- @usage
--  function add(a, x) return a + x end
--  list.fold(add, 0, {1,2,3}) --> 6
function fold(f, a, l, ...)
    for _, v in ipairs(l) do
        a = f(a, v, ...)
    end
    return a
end
reduce = fold

--- Finds the first value in the list which satisfies the predicate `f`.
-- @tparam function f The predicate.
-- @tparam table l The list.
-- @return[1] The found value.
-- @return[1] The found key.
-- @treturn[2] nil Nil if nothing satisfies the predicate.
function find(f, l)
    for k, v in ipairs(l) do
        if f(v, k) then return k, v end
    end
end

--- Calls a function on each element of a list in order.
-- @tparam function f
-- @tparam table l The list.
-- @param[opt] ... Extra arguments to f.
function each(f, l, ...)
    for k,v in ipairs(l) do
        f(v, k, ...)
    end
end

--- Reverses a list returning a new list.
-- @tparam table l The list to reverse.
-- @treturn table A reversed copy of `l`.
function reverse(l)
    local out = {}
    for i = #l, 1, -1 do
        insert(out, l[i])
    end
    return out
end

--- Performs a Fisher-Yates out of place shuffle on `l` returning the shuffled copy.
-- @tparam table l The list.
-- @treturn table The shuffled copy of the list.
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

function foldinc(f, t, ...)
    local a = t[1]
    for i = 2, #t do
        a = f(a, t[i], ...)
    end
    return a
end
--end-module--
return _ENV