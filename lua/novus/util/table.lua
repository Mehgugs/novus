--imports--
local vfold = require"novus.util.func".vfold
local pairs = pairs
local type = type
local get = rawget
local insert = table.insert
local setmetatable, getmetatable = setmetatable, getmetatable
--start-module--
local _ENV = {}
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

local function lazilymerge(A, B)
    return setmetatable(A, {
        __index = function(self, key)
            self[key] = B[key]
            return get(self, key)
        end
    })
end

function makelazy(a)
    return lazilymerge({}, a)
end

local function compile_inherit(a, ...)
    if ... then return lazilymerge(a, compile_inherit(...))
    else return a end
end

function inherit(...)
    return compile_inherit({}, ...)
end

function shallowcopy(t) return mergewith({}, t) end

local function deeplycopy(A, B)
    setmetatable(A, getmetatable(B))
    for k, v in pairs(B) do
        if type(v) == 'table' then
            A[k] = deeplycopy(A[k] or {}, v)
        else A[k] = v end
    end
    return A
end

function deepcopy(...)
    return vfold(deeplycopy, {}, ...)
end

inherit_this = compile_inherit

function default(v) return setmetatable({}, {__index = function() return v end}) end

function reflect(t)
    local new = {}
    for k, v in pairs(t) do
        new[k] = v
        new[v] = k
    end
    return new
end

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

function keys(t)
    local out = {}
    for k in pairs(t) do
        insert(out, k)
    end
    return out
end

function tcount(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

function weak() return setmetatable({}, {__mode = "k"}) end

function cache() return setmetatable({}, {__mode = "v"}) end

--end-module--
return _ENV