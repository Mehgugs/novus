--- User snowflake definition.
--  Dependencies: `snowflakes`, `novus.const`, `novus.api`
-- @module snowflakes.user
-- @alias user

--imports--
local util = require"novus.snowflakes.helpers"
local snowflake = require"novus.snowflakes"
local snowflakes = snowflake.snowflakes
local const = require"novus.const"
local api = require"novus.api"
local cqueues = require"cqueues"
local null = require"cjson".null
local setmetatable = setmetatable
local tonumber = tonumber
local gettime = cqueues.monotime
local running = cqueues.running
--start-module--
local _ENV = snowflake "user"

--- A discord user object.
--  Inherits from `snowflakes.snowflake`
-- @table user
-- @within Objects
-- @int id
-- @tparam number life
-- @tparam function cache
-- @tparam string username The user's username.
-- @tparam string discriminator The user's 4 digit discriminator.
-- @tparam string avatar The user's avatar hash.
-- @tparam boolean bot `true` iff. the user is a bot `false` otherwise.

schema {
     "username" --4
    ,"discriminator" --5
    ,"avatar" --6
    ,"bot"
    ,"mfa_enabled"
    ,"locale"
    ,"verified"
    ,"email"
    ,"dm_id"
}

function new_from(state, payload)
    return setmetatable({
         util.uint(payload.id)
        ,gettime()
        ,state.cache.methods.user
        ,payload.username
        ,payload.discriminator
        ,payload.avatar
        ,not not payload.bot
        ,not not payload.mfa_enabled
        ,payload.locale
    }, _ENV)
end

function email_scope(user, payload)
    user[9] = not not payload.verified
    user[10] = payload.email or ''
    return user
end

--- Gets the avatar url for the user.
--  @function user.avatar_url
--  @within Methods
--  @tparam user user
--  @tparam number size The size of the image to retreive, must be a power of 2.
--  @tparam string ext The image extension to use, defaults to either a `png` or `gif`.
--  @treturn string The url
--  @usage
--   user:avatar_url() --> https://cdn.discordapp.com/avatars/<id>/<hash>.png
function methods.avatar_url(user, size, ext)
    if user[6] then
        ext = ext or user[6]:startswith"_a" and 'gif' or 'png'
        local unsized = const.api.avatar_endpoint:format(user[1], user[6], ext)
        if size then
            return ("%s?size=%d"):format(unsized, size)
        else return unsized
        end
    else return methods.default_avatar(user, size)
    end
end

--- Gets the default avatar url for the user.
--  This is called by `user:avatar_url` to get the avatar if a custom one is not set.
--  @function user.default_avatar
--  @within Methods
--  @tparam user user
--  @tparam number size The size of the image to retreive, must be a power of 2.
function methods.default_avatar(user, size)
    local id = (tonumber(user[5]) % const.default_avatars)|0
    local unsized = const.api.default_avatar_endpoint:format(id)
    if size then
        return ("%s?size=%d"):format(unsized, size)
    else return unsized
    end
end

function methods.create_private_channel(user)
    local state = running():novus()
    local success, data, err = api.create_dM(state.api, {recipient_id = util.uint.tostring(user.id)})
    if success then
        local c = snowflakes.privatechannel.upsert(state, data)
        user.dm_id = c.id
        return c
    else
        return nil, err
    end
end

--- Get a private channel between the client and the user.
--  This method will create a channel if one does not exist.
--  @function user.private_channel
--  @within Methods
--  @tparam user user
--  @treturn privatechannel The private channel.
--  @treturn[2] nil
--  @treturn[2] string error string.
function methods.private_channel(user)
    if user.dm_id then
        return snowflakes.channel.get(user.dm_id)
    else return methods.create_private_channel(user)
    end
end

--- Sends a direct message to the user.
--  This is equivalent to `user:private_channel():send(...)`.
--  @function user.dm
--  @within Methods
--  @tparam user user
--  @tparam string str The content.
--  @tparam table|any ... Either: a table of options, or a string with optional format parameters. See @{textchannel.send} for more details.
--  @treturn message
--  @treturn[2] nil
--  @treturn[2] string error string.
function methods.dm(user, ...)
    local channel, err = methods.private_channel(user)
    if channel then
        return channel:send(...)
    else
        return nil, err
    end
end

--- Sets the username of the user.
--  This must be the current user (@{novus.client.me|`client:me()`})
--  @function user.set_username
--  @within Methods
--  @tparam user user The current user.
--  @tparam string nick The new username
--  @treturn[1] user
--  @treturn[2] nil
--  @treturn[2] string error string.
function methods.set_username(user, nick)
    local state = running():novus()
    if util.uint(state.app.id) == user[1] then
        local success, data, err = api.modify_current_user(state.api, {username = nick or null})
        if success then
            user[4] = data.username
            return user
        else return nil, err
        end
    else return false, "Cannot change someone else's username! (bot: %s; passed in: %s)" % {state.me, user}
    end
end

properties.name = util.alias(4)


function properties.tag(user)
    return ("%s#%s"):format(user[4], user[5])
end

function properties.default_avatar_kind(user)
    return (user[5] % const.default_avatars)|0
end

function properties.mention(user)
    return "<@%s>" % user[1]
end

function get_from(state, id)
    local cache = state.cache[__name]
    if cache[id] then return cache[id]
    else
        local success, data, err = api.get_user(state.api, id)
        if success then
            return new_from(state, data)
        else
            return nil, err
        end
    end
end

--- The full name format `user.username`#`user.discriminator`.
--  @within Properties
--  @tparam string tag

--- The type of default avatar assigned to the user.
--  @see novus.enums.defaultavatartype
--  @within Properties
--  @tparam number default_avatar_kind

--- The user's mention string.
--  @within Properties
--  @tparam string mention

--- The user's username.
--  @tparam string name
--  @within Properties


--end-module--
return _ENV