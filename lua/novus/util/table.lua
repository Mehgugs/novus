--- Table utilities.
-- Dependencies: `novus.util.func`
-- @module novus.util.table
-- @see novus.util
-- @alias _ENV

--imports--
local vfold = require"novus.util.func".vfold
local pairs = pairs
local type = type
local get = rawget
local insert = table.insert
local setmetatable, getmetatable = setmetatable, getmetatable
--start-module--
local _ENV = {}

--- Merges `B` on top of `A` in place.
-- @tab A
-- @tab B
-- @treturn table `A`
-- @usage
--  table.merge({foo = "", baz = "qux"}, {foo = "bar"})
--    --> {foo = "bar", baz = "qux"}
function mergewith(A, B)
    for k,v in pairs(B) do
        A[k] = v
    end
    return A
end

--- Merges arguments together into a new table.
-- @tab ... Tables to merge
-- @treturn table The resulting table.
function merge(...)
    return vfold(mergewith, {}, ...)
end

--- Merges arguments onto first argument.
-- @tab t The table to merge onto.
-- @tab ... Tables to merge.
-- @treturn table `t`
function overwrite(...) return vfold(mergewith, ...) end

local function lazilymerge(A, B)
    return setmetatable(A, {
        __index = function(self, key)
            self[key] = B[key]
            return get(self, key)
        end
    })
end

--- Makes a table which loads entries from `a` as they are accessed.
-- @tab a The table to lazily copy
-- @treturn table An empty table that will fill as it is accessed.
function makelazy(a)
    return lazilymerge({}, a)
end

local function compile_inherit(a, ...)
    if ... then return lazilymerge(a, compile_inherit(...))
    else return a end
end

--- Makes a table which inherits from multiple sources.
-- @see table.makelazy
-- @tab ... Tables to lazily copy from.
-- @treturn An empty table that will fill as it is accessed.
function inherit(...)
    return compile_inherit({}, ...)
end

--- Makes a shallow copy of the table `t`.
-- @tab t The table to copy.
-- @treturn table A shallow copy of `t`.
function shallowcopy(t) return mergewith({}, t) end

function deeplycopy(A, B, level)
    for k, v in pairs(B) do
        if type(v) == 'table' then
            A[k] = deeplycopy(A[k] or {}, v)
        else A[k] = v end
    end
    setmetatable(A, getmetatable(B))
    return A
end

--- Deeply copies the table `t`.
-- @tab t The table to deeply copy.
-- @treturn table The deep copy of `t`.
function deepcopy(...)
    return vfold(deeplycopy, {}, ...)
end

inherit_this = compile_inherit

--- Creates a table whose default value is `v`.
-- @param v The default value.
-- @treturn table
-- @usage
--  T = table.default"novus"
--  T.foo --> "novus"
function default(v) return setmetatable({}, {__index = function() return v end}) end

--- Reflects the table `t` into a new table.
-- @tab t
-- @treturn table The result.
-- @usage
--  table.reflect{foo = "bar"} --> {foo = "bar", bar = "foo"}
function reflect(t)
    local new = {}
    for k, v in pairs(t) do
        new[k] = v
        new[v] = k
    end
    return new
end

--- Checks if `w` is a subtable of `U`.
-- @tab U
-- @tab w
-- @treturn boolean
function subtable(U, w)
    for  k,v in pairs(w) do
        if type(v) == 'table' and not subtable(U[k], v) then
            return false
        elseif type(v) ~= "table" and U[k] ~= v then
            return false
        end
    end
    return true
end

--- Returns an array of the keys of `t`.
-- @tab t
-- @treturn table The key array.
function keys(t)
    local out = {}
    for k in pairs(t) do
        insert(out, k)
    end
    return out
end

--- Counts the number of pairs contained in `t`
-- @tab t
-- @treturn number
function tcount(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

--- Creates a weak key table.
-- @treturn table
function weak() return setmetatable({}, {__mode = "k"}) end

--- Creates a weak value table.
-- @treturn table
function cache() return setmetatable({}, {__mode = "v"}) end

--end-module--
return _ENV