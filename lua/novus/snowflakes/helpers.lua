--imports--
local util = require"novus.util"
local tab  = require"novus.util.table"
local warn = util.warn
local running = require"cqueues".running
local setmetatable = setmetatable
local ipairs = ipairs
local set = rawset
local rawget = rawget
--start-module--
local _ENV = util.inherit(util)

function alias(key)
    return function(obj) return obj[key] end
end

function makenewindex(_ENV) --luacheck:ignore
    return function(obj, key, val)
        if schema[key] then
            return set(obj, schema[key], val)
        else return set(obj, key, val)
        end
    end
end

function makeindex(_ENV) --luacheck:ignore
    return function(snowflake, key)
        if methods[key] then return methods[key]
        elseif schema[key] and snowflake[schema[key]] ~= nil then return snowflake[schema[key]]
        elseif properties[key] then return properties[key](snowflake)
        elseif constants[key] then return constants[key]
        end
    end
end

function makeget(_ENV) --luacheck:ignore
    return function(...) return get_from(running():novus(), ...) end
end

function makenew(_ENV) --luacheck:ignore
    return function (...) return new_from(running():novus(), ...) end
end

function new_schema ()
    local len = {}
    return setmetatable({[len] = 0}, {__call = function(s, items)
        for _, v in ipairs(items) do
            s[len] = s[len] + 1
            s[v] = s[len]
        end
        return s[len]
    end}), len
end

function wrap_defs(obj, key, val)
    if key == 'new_from' then
        set(obj, key, function(...)
            local out = val(...)
            if not out.cache then
                util.warn("%s will not be cached [%s]", out ,out[3])
            end
            return out.cache and out:cache() or out
        end)
    else
        set(obj, key, val)
    end
end

function snowflake_inherit(self, base, name)
    local next = tab.deeplycopy({}, base)
    if next.constants == nil then
        tab.deeplycopy({}, base, 0)
        util.fatal("%s %s %s %s", self, base, base.constants, rawget(base,"constants"))
    end
    next.__name = name
    next.__index = makeindex(next)
    next.__newindex = makenewindex(next)
    next.constants.__schema = next.schema
    next.constants.kind = name
    next.get = makeget(next)
    next.new = makenew(next)
    self.snowflakes[name] = next
    return setmetatable(next, {
         __name = "%s-behaviour" % name
        ,__call = function(...) return snowflake_inherit(self, ...) end
        ,__newindex = wrap_defs
    })
end


function snowflake_root()
    return setmetatable({snowflakes = {}}, {
     __name = "snowflake-behaviour"
    ,__call = function(self, name)
        return snowflake_inherit(self, self, name)
    end})
end

--end-module--
return _ENV