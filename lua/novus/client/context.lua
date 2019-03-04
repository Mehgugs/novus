--- Context object returned in events.
--  Dependencies: `snowflakes`, `util`
-- @module client.context
-- @alias _ENV

--imports--
local util = require"novus.util"
local snowflake = require"novus.snowflakes"
local emitter = require"novus.client.emission".new
local promise = require"cqueues.promise"
local cqueues = require"cqueues"
local snowflakes = snowflake.snowflakes
local sleep = cqueues.sleep
local running = cqueues.running
local poll = cqueues.poll
local unpack = table.unpack
local setmetatable = setmetatable
local type = type
local pairs = pairs
local assert = assert
local get = rawget
local includes = util.includes
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
        return assert(p())
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
-- @within Methods
-- @tparam context ctx
-- @string field
-- @param value
function context.add_extra(ctx, field, value)
    local val = get(ctx, field) or ctx.promised[field]
    if val ~= nil then return ctx
    elseif val == nil and promise.type(value) then ctx.promised[field] = value return ctx
    else ctx[field] = value return ctx
    end
end

--- Interposition mechanism for adding new methods to the context object.
-- @string name The method name to interpose.
-- @func value The function value to interpose.
-- @treturn[opt] func The old method, if it exists.
function interpose(name , value)
    assert(name ~= "properties", "Cannot overwrite properties!")
    local old = context[name]
    context[name] = value
    return old
end

function interpose_prop(name , value)
    local old = context.properties[name]
    context.properties[name] = value
    return old
end

--- Wrapper around `ctx.channel:send`.
--  @within Methods
--  @tparam context ctx
--  @param ... Arguments to @{channel:send|snowflakes.channel.send}
--  @treturn[1] message
--  @treturn[2] nil
--  @treturn[2] string error message
function context.send(ctx, ...)
    assert(ctx.channel and ctx.channel.send, "Cannot send messages to a %s." % ctx.channel)
    return ctx.channel:send(...)
end

function context.properties.client()
    return running():novus()
end

function context.properties.USER_REPLIED(ctx)
    local uid = snowflake.id(ctx.user)
    local chid = snowflake.id(ctx.channel)
    local em = ctx.client.events.MESSAGE_CREATE
    >> function(ntx)
        return ntx, ntx.user.id == uid and ntx.channel.id == chid
    end
    >> emitter()
    ctx:add_extra('USER_REPLIED', em)
    return em
end

function context.properties.from_my_user(ctx)
    local uid = snowflake.id(ctx.user)
    local chid = snowflake.id(ctx.channel)
    local function predicate(ntx)
        if (uid and ntx.user.id == uid) and (chid and ntx.channel.id == chid) then
            return ntx, true
        end
    end
    ctx:add_extra("from_my_user", predicate)
    return predicate
end

local function both(f, g)
    return function(...)
        return f(...) and g(...)
    end
end

local function users_next_such_that(ctx, name)
    local name, pred, timeout = name[1], name.such_that, name[2]
    assert(name and pred, "Could not parse arguments to ctx:users_next .")
    local em = ctx.client.events[name]
    return em:await(both(ctx.from_my_user, pred), timeout)
end

--- Wrapper around the `client.events` emitters.
--  This will wait for the next event such that the context.user is the current user.
--  @within Methods
--  @tparam context ctx
--  @tparam string|table name The event name to wait for. Or a table of the form `{name, such_that = func; timeout}`.
--  @tparam number|nil timeout The timeout in seconds (unused if name is a table).
--  @see client.emission.await
--  @return The event emitted.
function context.users_next(ctx, name, timeout)
    if type(name) == 'table' then
        return users_next_such_that(ctx, name)
    else
        local em = ctx.client.events[name]
        return em:await(ctx.from_my_user, timeout)
    end
end

function context.properties.USER_REACTED(ctx)
    local uid = snowflake.id(ctx.user)
    local chid = snowflake.id(ctx.channel)
    local mid = snowflake.id(ctx.msg)
    local em = ctx.client.events.MESSAGE_REACTION_ADD
    >> function(ntx)
        if  (snowflake.id(ntx.user) or ntx.reaction.user_id) == uid
        and (snowflake.id(ntx.channel) or ntx.reaction.channel_id == chid)
        and (snowflake.id(ntx.msg) or ntx.reaction.message_id == mid) then
            ntx:add_extra('reacted_with', ntx.reaction.nonce or snowflakes.reaction.properties.nonce(ntx.reaction))
            return ntx, true
        end
    end
    >> emitter()
    ctx:add_extra('USER_REACTED', em)
    return em
end


--end-module--
return _ENV