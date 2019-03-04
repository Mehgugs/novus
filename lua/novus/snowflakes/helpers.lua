--imports--
local util = require"novus.util"
local tab  = require"novus.util.table"
local warn = util.warn
local running = require"cqueues".running
local inserter = require"novus.cache".inserter
local setmetatable = setmetatable
local ipairs, pairs = ipairs, pairs
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

function makeupdatefrom(_ENV) --luacheck:ignore
    return function(state, snowflake, payload)
        for k, v in pairs(payload) do
            if processor[k] or (schema[k] and schema[k] >= 4) then
                local proc = processor[k]
                if proc then
                    local value, key = proc(v, state, snowflake)
                    key = key or k
                    if schema[key] == nil then util.throw("%s -> %s not stored in schema", k, key) end
                    snowflake[schema[key]] = value
                else
                    snowflake[schema[k]] = v
                end
            end
        end
        return snowflake
    end
end

function makeupdate(_ENV) --luacheck:ignore
    return function(...)
        return update_from(running():novus(), ...)
    end
end

function makeupsert(_ENV)
    return function(client, payload, guild_id)
        local id = util.uint(payload.id)
        local cached = client.cache[__name]
        if cached then
            if guild_id then payload.guild_id = guild_id end
            local mycache = guild_id and cached[guild_id] or cached
            if mycache == nil and guild_id then
                mycache = util.cache()
                client.cache[__name][guild_id] = mycache
                client.cache[__name].methods[guild_id] = inserter(mycache)
            end
            local obj = mycache[id]
            if obj then return update_from(client, obj, payload)
            else return new_from(client, payload)
            end
        else
            return new_from(client, payload)
        end
    end
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
            return out.cache and out:cache() or out
        end)
    else
        set(obj, key, val)
    end
end

function snowflake_inherit(self, base, name)
    local next = tab.deeplycopy({}, base)
    next.__name = name
    next.__index = makeindex(next)
    next.__newindex = makenewindex(next)
    next.constants.__schema = next.schema
    next.constants.kind = name
    next.get = makeget(next)
    next.new = makenew(next)
    next.update_from = makeupdatefrom(next)
    next.update = makeupdate(next)
    next.upsert = makeupsert(next)
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