--imports--
local util = require"novus.snowflakes.helpers"
local const = require"novus.const"
local gettime = require"cqueues".monotime
local lifetimes = const.lifetimes
--start-module--
local _ENV = util.snowflake_root()

__name = "snowflake"

schema = util.new_schema()

schema {
     "id"
    ,"life"
    ,"cache"
}

function __eq(A, B)
    return A[1] == B[1] 
end 

methods, properties, constants = {}, {}, {}

function properties.created_at(obj)
    return util.Date.fromSnowflake(obj[1])
end

function properties.timestamp(obj) return createdAt(obj):toISO() end

function get_from(state, snowflake)
    return util.throw("Could not get a new a %s; it does not implement snowflake.get!", snowflake.__name)
end

__index = methods
__newindex = util.makenewindex(_ENV)

function __gc(snowflake)
    if snowflake[3] and gettime() - snowflake[2] <= lifetimes[snowflake.__name] then 
        return snowflake[3](snowflake)
    end
end

function destroy_from(state, snowflake)
    local cache = state.cache[snowflake.__name]
    snowflake[3] = nil
    if cache then cache[snowflake[1]] = nil end
end

function destroy(snowflake)
    return destroy_from(running():novus(), snowflake)
end

constants.cachable = true
constants.virtual = false 

--end-module--
return _ENV