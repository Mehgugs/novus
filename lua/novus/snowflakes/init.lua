--imports--
local util = require"novus.snowflakes.helpers"
local const = require"novus.const"
local gettime = require"cqueues".monotime
local lifetimes = const.lifetimes
local next = next
local type = type
--start-module--
local _ENV = util.snowflake_root()

__name = "snowflake"

local _schema, sc_len = util.new_schema()

schema = _schema

schema {
     "id"
    ,"life"
    ,"cache"
}

function __eq(A, B)
    return A[1] == B[1]
end

function id(v)
    if v and type(v) == 'table' and v[_ENV] then
        return v[1]
    else
        return util.uint(v)
    end
end

methods, properties, constants = {}, {}, {}

function properties.created_at(obj)
    return util.Date.fromSnowflake(obj[1])
end

function properties.timestamp(obj) return createdAt(obj):toISO() end

function get_from()
    return util.throw("snowflake.get not implemented.")
end

__index = methods
__newindex = util.makenewindex(_ENV)

function __gc(snowflake)
    if snowflake[3] and gettime() - snowflake[2] <= lifetimes[snowflake.__name] then
        return snowflake[3](snowflake)
    end
end
function __tostring(snowflake)
    retrn ("%s: %u"):format(snowflake.kind, snowflake[1])
end
local function snowflake_iter(invar, state)
    local key, idx = next(invar.__schema, state)
    if key ~= sc_len then
        return key, invar[idx]
    else
        return snowflake_iter(invar, key)
    end
end

function __pairs(snowflake)
    return snowflake_iter, snowflake
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
constants[_ENV] = true

--end-module--
return _ENV