--imports--
local util = require"novus.util"
local running = require"cqueues".running
local setmetatable = setmetatable
local ipairs = ipairs
local set = rawset
--start-module--
local _ENV = util.inherit(util)

function alias(key) 
    return function(obj) return obj[key] end 
end 

function makenewindex(env)
    local _ENV = env 
    return function(obj, key, val)
        if schema[key] and obj[schema[key]] then 
            util.throw("%s-%s cannot have property %s overwritten!", __name, obj.id, key)
        else return set(obj, key, val)
        end
    end
end

function makeindex(env)
    local _ENV = env 
    return function(snowflake, key)
        if methods[key] then return methods[key] 
        elseif schema[key] then return snowflake[schema[key]]
        elseif properties[key] then return properties[key](snowflake)
        elseif constants[key] then return constants[key]
        end
    end
end

function makeget(env)
    local _ENV = env 
    return function(...) return get_from(running():novus(), ...) end 
end

function makenew(env)
    local _ENV = env 
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
    end})
end


function snowflake_root()
    return setmetatable({snowflakes = {}}, {
    __call = function(self, name) 
        local next = deepcopy(self)
        next.__name = name 
        next.__index = makeindex(next)
        next.__newindex = makenewindex(next)
        next.get = makeget(next)
        next.new = makenew(next)
        self.snowflakes[name] = next
        return setmetatable(next, {__name = "%s-behaviour" % name})
    end})
end

--end-module--
return _ENV