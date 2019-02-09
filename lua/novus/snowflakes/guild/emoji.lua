--imports--
local api = require"novus.api"
local util = require"novus.snowflakes.helpers"
local snowflake = require"novus.snowflakes"
local const = require"novus.const"
local cqueues = require"cqueues"
local null = require"cjson".null
local setmetatable = setmetatable
local gettime = cqueues.monotime
local running = cqueues.running
local snowflakes = snowflake.snowflakes
--start-module--
local _ENV = snowflake "emoji"

schema {
     "guild_id"
    ,"name"
    ,"roles"
    ,"user_id"
    ,"require_colons"
    ,"managed"
    ,"animated"
}

function processor.user(payload, state)
    local uid
    if payload.user then
        uid = util.uint(payload.user.id)
        if not state.cache.user[uid] then
            snowflakes.user.new_from(state, payload.user, state.cache.methods.user)
        end
    end
    return uid, "user_id"
end

function new_from(state, payload)
    return setmetatable({
         util.uint(payload.id)
        ,gettime()
        ,state.cache.methods.emoji
        ,payload.guild_id
        ,payload.name
        ,payload.roles or {}
        ,processor.user(payload, state)
        ,payload.require_colons
        ,payload.managed
        ,payload.animated
    }, _ENV)
end

function modify(emoji, by)
    local state = running():novus()
    local success, data, err = api.modify_guild_emoji(state.api, emoji[4], emoji[1], by)
    if success and data then
        return new_from(state, data, emoji)
    else
        return false, err
    end
end

function methods.set_name(emoji, name)
    return modify(emoji, {name = name or null})
end

function methods.set_roles(emoji, roles)
    return modify(emoji, {roles = roles or null})
end

function methods.delete(emoji)
    local state = running():novus()
    if emoji[4] then
        local success, data, err = api.delete_guild_emoji(state.api, emoji[4], emoji.id)
        if success and data then
            emoji:destroy()
            return true
        else
            return false, err
        end
    end
end

function methods.has_role(emoji, id)
    return util.includes(emoji[6], id)
end

function properties.guild(emoji)
    return emoji[4] and snowflakes.guild.get(emoji[4])
end

function properties.url(emoji)
    return const.api.emoji_endpoint % {emoji.id, emoji[10] and 'gif' or 'png'}
end

function properties.nonce(emoji)
    return emoji[5] .. ":" .. emoji.id
end

function properties.mention(emoji)
    return (emoji[10] and "<a:%s>" or "<:%s>") % emoji.nonce
end

function properties.role_objects(emoji)
    return view.new(running():novus().cache.role, function(key, value, s)
        return includes(s, key) and value
    end, emoji[6])
end

function get_from(state, guild_id, id)
    local cache = state.cache[__name]
    if cache[id] then return cache[id]
    else
        local success, data, err = api.get_guild_emoji(state.api, guild_id, id)
        if success then
            data.guild_id = guild_id
            return new_from(state, data)
        else
            return nil, err
        end
    end
end

--end-module--
return _ENV