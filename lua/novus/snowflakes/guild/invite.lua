--imports--
local util = require"novus.snowflakes.helpers"
local snowflake = require"novus.snowflakes"
local setmetatable = setmetatable
local snowflakes = snowflake.snowflakes
--start-module--
local _ENV = snowflake "invite"

schema {
     "guild_id"
    ,"code"
    ,"channel_id"
    ,"approximate_presence_count"
    ,"approximate_member_count"
    ,"inviter_id"
    ,"uses"
    ,"max_uses"
    ,"max_age"
    ,"temporary"
    ,"created_at"
    ,"revoked"
}

function new_from(state, payload)
    local guild = payload.guild
    local gid
    if guild then
        gid = util.uint(guild.id)
        if not state.cache.guild[gid] then
            snowflakes.guild.new_from(state, guild, state.cache.methods.guild)
        end
    end
    local channel = payload.channel
    local chid = util.uint(channel.id)
    if not state.cache.channel[chid] then
        snowflakes.user.new_from(state, channel, state.cache.methods.channel)
    end
    local inviter = payload.inviter
    local uid
    if inviter then
        uid = util.uint(inviter.id)
        if not state.cache.user[uid] then
            snowflakes.user.new_from(state, user, state.cache.methods.user)
        end
    end
    return setmetatable({
         payload.code
        ,gettime()
        ,nil
        ,gid or nil
        ,payload.code
        ,chid
        ,payload.approximate_presence_count
        ,payload.approximate_member_count
        ,uid
        ,payload.uses
        ,payload.max_uses
        ,payload.max_age
        ,payload.temporary
        ,payload.created_at
        ,payload.revoked
    }, _ENV)
end

function methods.delete(invite)
    local state = running():novus()
    local success, data, err = api.delete_invite(state.api, invite[1])
    if success and data then
        emoji:destroy()
        return true
    else
        return false, err
    end
end

function properties.guild(invite)
    return invite[4] and snowflakes.guild.get(invite[4]) or nil
end

function properties.inviter(invite)
    return invite[9] and snowflakes.user.get(invite[9]) or nil
end

function properties.channel(invite)
    return snowflakes.channel.get(invite[6])
end

function properties.created_at(obj)
    return util.Date.fromISO(obj[14], true)
end

function get_from(state, guild_id, id)
    local success, data, err = api.get_guild_invite(state.api, guild_id, id)
    if success then
        return new_from(state, data)
    else
        return nil, err
    end
end

constants.cachable = false
constants.virtual = true
--end-module--
return _ENV