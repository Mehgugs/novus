--- Snowflake object protocol.
--  Dependencies: `novus.const`
-- @module snowflakes
-- @alias _ENV

--imports--
local util = require"novus.snowflakes.helpers"
local const = require"novus.const"
local cache = require"novus.cache"
local cqueues = require"cqueues"
local gettime = cqueues.monotime
local lifetimes = const.lifetimes
local next = next
local type = type
local min = math.min
local running = cqueues.running
--start-module--
local _ENV = util.snowflake_root()

__name = "snowflake"

--- Abstract snowflake object.
-- @table snowflake
-- @within Objects
-- @tparam Date created_at The date the snowflake was created at.
-- @int timestamp The unix timestamp the snowflake was created at.

local _schema, sc_len = util.new_schema()

schema = _schema

schema {
     "id"
    ,"life"
    ,"cache"
}

--- == metamethod, comparison between two snowflake objects.
-- @tparam snowflake A
-- @tparam snowflake B
-- @treturn bool `true` iff. `A.id == B.id` `false` otherwise.
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

methods, properties, constants, processor = {}, {}, {}, {}

function properties.created_at(obj)
    return util.Date.fromSnowflake(obj[1])
end

function properties.timestamp(obj) return util.uint.timestamp(obj[1]) end

function get_from()
    return util.throw("snowflake.get not implemented.")
end

__index = methods
__newindex = util.makenewindex(_ENV)

--- __gc finalizer for caching protocol.
-- @tparam snowflake snowflake The snowflake object
function __gc(snowflake)
    if snowflake[3] and gettime() - snowflake[2] <= lifetimes[snowflake.__name] then
        return snowflake[3](snowflake)
    end
    cache.counts[snowflake.kind] = min((cache.counts[snowflake.kind] or 0)-1, 0)
end

--- tostring metamethod.
-- @tparam snowflake snowflake
-- @treturn string A string representation of the snowflake.
function __tostring(snowflake)
    return ("%s: %s"):format(snowflake.kind, not snowflake.virtual and util.uint.tostring(snowflake[1]) or "un-identified")
end

local function snowflake_iter(invar, state)
    local key, idx = next(invar.__schema, state)
    if key ~= sc_len then
        return key, invar[idx]
    else
        return snowflake_iter(invar, key)
    end
end

--- `pairs` iterator
-- @tparam snowflake snowflake
function __pairs(snowflake)
    return snowflake_iter, snowflake
end

function destroy_from(state, snowflake)
    local cache = state.cache[snowflake.__name]
    snowflake[3] = nil
    if cache then cache[snowflake[1]] = nil end
end

--- Destroys a snowflake object, uncaching it.
-- @tparam snowflake snowflake
function destroy(snowflake)
    return destroy_from(running():novus(), snowflake)
end

-- function methods.cache(snowflake)
--     util.warn("cache called on a snowflake without a cacher (%s)", snowflake)
-- end

constants.cachable = true
constants.virtual = false
constants[_ENV] = true

--end-module--
return _ENV
