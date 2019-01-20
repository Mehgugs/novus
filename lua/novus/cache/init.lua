--imports--
local util = require"novus.util"
local ipairs = ipairs
--start-module--
local _ENV = {}

local cachable_entities = {
     "user"
    ,"guild"
    ,"member"
    ,"channel"
    ,"emoji"
    ,"role"
    ,"reaction"
}

function inserter(cache)
    return function(object)
        local id = object.id
        local old = cache[id]
        if old then
            old.cache = nil
        end
        cache[id] = object
    end
end

function new()
    local cache = {methods = {}}
    for _, v in ipairs(cachable_entities) do
        local new = util.cache()
        cache[v] = new
        cache.methods[v] = inserter(new)
    end
    -- special case for messages
    cache.message = {}
    cache.methods.message = {}
    return cache
end
--end-module--
return _ENV