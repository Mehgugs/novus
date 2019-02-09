--- Caching mechanism for novus.
-- Dependencies: `novus.util`
-- @module novus.cache
-- @alias _ENV

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
            old[3] = nil
        end
        cache[id] = object
        return object
    end
end

--- Constructs a new cache object.
-- @treturn cache
function new()
    local cache = {methods = {}}
    for _, v in ipairs(cachable_entities) do
        local new = util.cache()
        cache[v] = new
        cache.methods[v] = inserter(new)
    end
    -- special case for messages & members
    cache.message = {}
    cache.methods.message = {}
    cache.member = {}
    cache.methods.member = {}
    return cache
end

--- A collection of weak tables which collect snowflakes.
-- @table cache
-- @within Objects
-- @see cache.new
-- @tab methods Closures for caching specific snowflake types.
-- @tab type Each cachable snowflake type has a table inside the cache, where objects of that type are kept.

--end-module--
return _ENV
