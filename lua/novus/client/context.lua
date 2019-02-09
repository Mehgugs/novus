--- Context object returned in events.
--  Dependencies: `novus.snowflakes`
-- @module novus.client.context
-- @alias _ENV

--imports--
local snowflake = require"novus.snowflakes"
local unpack = table.unpack
local setmetatable = setmetatable
local type = type
local pairs = pairs
--start-module--
local _ENV = {}

--- An object for holding the various objects emitted in events.
-- @table context
-- @within objects
-- @field guild The guild involved in the request.
-- @field channel The channel involved in the request.
-- @field user The user object involved in the request.
-- @field member The member object involved in the request.
-- @field role The role involved in the request.
-- @field msg The msg involved in the request.
-- @usage
--  -- Example
--  client.events.MESSAGE_CREATE :listen (function(ctx)
--      ctx.channel:send{embed = {
--          title = ctx.guild.name
--          description = "%s sent a message." % ctx.user
--      }}
--  end)

local function ctor(_, g_or_options, ...)
    if snowflake.id(g_or_options) == nil and type(g_or_options) == 'table' then
        return with_options(g_or_options)
    else
        return with_args(g_or_options, ...)
    end
end

setmetatable(_ENV, {__call = ctor})

function with_options(ops)
    local ctx = with_args(unpack(ops))
    for k , v in pairs(ops) do
        if type(k) == 'number' and 1 <= k and k <= #ops then
            goto continue
        end
        ctx:add_extra(k, v)
        ::continue::
    end
    return ctx
end

context = {properties={}}

function __index (ctx, key)
    if context[key] then
        return context[key]
    elseif context.properties[key] then
        return context.properties[key](ctx)
    end
end

function with_args(guild, channel, user, role, msg)
    return setmetatable({
         guild = guild
        ,channel = channel
        ,user = user and user.kind == "user" and user
        ,member = user and user.kind == "member" and user
        ,role = role
        ,msg = msg
    }, _ENV)
end

--- Adds a new key value pair into the context object
-- @tparam context ctx
-- @string field
-- @param value
function context.add_extra(ctx, field, value)
    if ctx[field] ~= nil then return ctx
    else ctx[field] = value return ctx
    end
end

--- Interposition mechanism for adding new methods to the context object.
-- @string name The method name to interpose.
-- @func value The function value to interpose.
-- @treturn[opt] func The old method, if it exists.
function interpose(name , value)
    local old = context[name]
    context[name] = value
    return old
end

--end-module--
return _ENV