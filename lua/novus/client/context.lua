--- Context object returned in events.
--  Dependencies: `novus.snowflakes`
-- @module novus.client.context
-- @alias _ENV

--imports--
local util = require"novus.util"
local snowflake = require"novus.snowflakes"
local promise = require"cqueues.promise"
local unpack = table.unpack
local setmetatable = setmetatable
local type = type
local pairs = pairs
local assert = assert
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
    elseif ctx.promised[key] then
        local p = ctx.promised[key]
        ctx.promised[key] = nil
        local success, value = assert(p())
        util.info("%s, %s", success, value)
        return  success and value
    elseif context.properties[key] then
        return context.properties[key](ctx)
    end
end

function with_args(guild, channel, user, role, msg)
    local pc, pu, pr, pm =
         promise.type(channel)
        ,promise.type(user)
        ,promise.type(role)
        ,promise.type(msg)
    return setmetatable({
         guild = guild
        ,channel = not pc and channel or nil
        ,user = not pu and user and user.kind == "user" and user or nil
        ,member = not pu and user and user.kind == "member" and user or nil
        ,role = not pr and role or nil
        ,msg = not pm and msg or nil
        ,promised = {
             channel = pc and channel or nil
            ,user = pu and user or nil
            ,role = pr and role or nil
            ,msg = pm and msg or nil
        }
    }, _ENV)
end

--- Adds a new key value pair into the context object
-- @tparam context ctx
-- @string field
-- @param value
function context.add_extra(ctx, field, value)
    if ctx[field] ~= nil then return ctx
    elseif ctx[field] == nil and promise.type(value) then ctx.promised[field] = value return ctx
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