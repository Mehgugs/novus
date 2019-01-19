--imports--
local util = require"novus.util"
local setmetatable = setmetatable 
local next = next
--start-module--
local _ENV = {}

function new(t, f, a, m)
    return setmetatable({}, {
         __mode = v
        ,__index = util.bind(__index, t,f,a,m)
        ,__pairs = __pairs
    })
end

function __index(t, f, a, m, view, key)
    local raw = view.__t[key]
    if raw and view.__f(key, raw, view.__a) then 
        view[key] = m and m(key, raw) or raw
        return raw 
    end
end

function ignores_value(_, value, comp)
    return value ~= comp 
end

function ignores_key(key, _, comp)
    return key ~= comp 
end

function remove(view, value)
    return new(view, ignores_value, value)
end

function remove_key(view, key)
    return new(view, ignores_key, key)
end 

local ignore_keys = {
    __t = true, 
    __f = true,
    __a = true,
    __m = true
}

local function view_iter(invar, state)
    local key = next(invar, state)
    if ignore_keys[key] then 
        return view_iter(invar, key)
    else
        return key, invar[key]
    end
end

function __pairs(view)
    return view_iter, view
end 

function flatten(view)
    for _ in __pairs(view) do end
end

function add(view, item)
    if view.__f == ignores_value and view.__a == item then 
        return view.__t 
    end
end
local ident = function() return true end
function from(t, m)
    return new(t, ident, nil, m)
end

view.identity = ident

--end-module--
return _ENV