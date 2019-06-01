--- Object for a read-only view into a table.
-- @module cache.view
-- @alias _ENV

--imports--
local getmetatable = getmetatable
local setmetatable = setmetatable
local next = next
local get = rawget
local throw = require"novus.util.printf".throw
--start-module--
local _ENV = {}

--- A view of a table.
-- This is constructed by `view.new`.
-- Its fields are the same as the table it's viewing,
-- except when the predicate map returns nil.
-- @see view.new
-- @table view
-- @within Objects

--- Construct a new view of the table `t`.
-- @tab t The table to view.
-- @func f A function which is called with the key, value from `t`, its return value is
-- the value `view[key]` returns, if it returns nil no value is returned.
-- @param a An argument to `f`.
-- @treturn view
-- @usage
--  v = view.new({1,2,3}, function(_, x) return 2*x end)
--  v[1] --> 2
function new(t, f, a)
    if t == nil then throw("Cannot view nil!") end
    local d = 1
    if getmetatable(t) == _ENV then
        d = t.__d + 1
    end
    return setmetatable({__t = t, __f = f, __a = a, __d =d}, _ENV)
end

function __index(view, key)
    local t, f, a = get(view, "__t"), get(view, "__f"), get(view, "__a")
    local raw = t[key]
    if raw ~= nil then
        local val = f(key, raw, a)
        return val or nil
    end
end

function __newindex() end

function ignores_value(_, value, comp)
    return value ~= comp and value
end

function ignores_key(key, value, comp)
    return key ~= comp and value
end

--- Returns a view which can see all values inside the table,
-- except the one specified.
-- @tab view The table (can be a view) to view.
-- @param value The value to ignore.
-- @treturn view
-- @usage
--  t = {1,2,3,4,5}
--  v = view.remove(t, 4)
--  t[4], v[4] --> 4, nil
function remove(view, value)
    return new(view, ignores_value, value)
end

--- Returns a view which can see all values inside the table,
-- except the one accessed by the key specified.
-- @tab view The table (can be a view) to view.
-- @param key The key to ignore.
-- @treturn view
-- @usage
--  t = {"foo", "bar", "baz"}
--  v = view.remove_key(t, 1)
--  t[1], v[1] --> "foo", nil
function remove_key(view, key)
    return new(view, ignores_key, key)
end

local function view_next(invar, state)
    if getmetatable(invar) == _ENV then
        return view_next(invar.__t, state)
    else
        return next(invar, state)
    end
end

local function view_iter(invar, state)
    local key = view_next(invar, state)
    if key and invar[key] == nil then
        return view_iter(invar, key)
    end
    return key, invar[key]
end

--- View pairs iterator.
-- @view view The view to iterate over.
-- @usage
-- v = view.remove({1,2,3}, 1)
-- for k,v in pairs(v) do print(k, v) end
--  --> 2  2
--  --> 3  3
function __pairs(view)
    return view_iter, view
end

--- Flattens a view of views into a table.
-- @view view The view to flatten.
-- @treturn table A plain table of the key value pairs the view can see.
-- @usage
--  v = view.remove({1,2,3}, 1)
--  view.flatten(v) --> {nil, 2, 3}
function flatten(view)
    local out = {}
    for k,v in __pairs(view) do out[k] = v end
    return out
end

limit = 32


--- An identity view function.
-- @function identity
identity = function(_, x) return x end

--- Creates a view copy of a table (or view).
--  Shorthand for `view.new(t, view.identity)`.
-- @tab t The table to copy.
-- @treturn view The view copy.
function copy(t)
    return new(t, identity)
end

local function selector(_, tbl, props)
    local out = {}
    for i = 1, props.n do 
        out[i] = props[i] ~= nil and tbl[props[i]] or nil
    end 
    out.n = props.n
    return out
end

function select(view, ...)
    return new(view, selector, pack(...))
end

__name = "view"

--end-module--
return _ENV