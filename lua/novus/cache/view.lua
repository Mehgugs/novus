--imports--
local getmetatable = getmetatable
local setmetatable = setmetatable
local next = next
--start-module--
local _ENV = {}

function new(t, f, a)
    return setmetatable({__t = t, __f = f, __a = a}, _ENV)
end

function __index(view, key)
    local raw = view.__t[key]
    if raw ~= nil then
        local val = view.__f(key, raw, view.__a)
        return val or nil
    end
end

function ignores_value(_, value, comp)
    return value ~= comp and value
end

function ignores_key(key, value, comp)
    return key ~= comp and value
end

function remove(view, value)
    return new(view, ignores_value, value)
end

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
    return key, invar[key]
end

function __pairs(view)
    return view_iter, view
end

function flatten(view)
    local out = {}
    for k,v in __pairs(view) do out[k] = v end
    return out
end

identity = function(_, x) return x end

function copy(t)
    return new(t, identity)
end

--end-module--
return _ENV