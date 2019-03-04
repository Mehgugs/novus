--- Caching mechanism for novus.
-- Dependencies: `util`
-- @module cache
-- @alias _ENV

--imports--
local interposable = require"novus.client.interposable"
local util = require"novus.util"
local ipairs = ipairs
local eq = rawequal
--start-module--
local _ENV = interposable{}

local cachable_entities = {
     "channel"
    ,"emoji"
    ,"role"
    ,"reaction"
}

function inserter(cache)
    return function(object)
        local id = object.id
        local old = cache[id]
        if old and not eq(old, object) then
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
        local new = {}
        cache[v] = new
        cache.methods[v] = inserter(new)
    end
    cache.user = util.cache()
    cache.methods.user = inserter(cache.user)
    cache.guild = {}
    cache.methods.guild = inserter(cache.guild)
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
