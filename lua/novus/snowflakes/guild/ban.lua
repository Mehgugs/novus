--imports--
local api = require"novus.api"
local util = require"novus.snowflakes.helpers"
local snowflake = require"novus.snowflakes"
local gettime = require"cqueues".monotime
local setmetatable = setmetatable
local snowflakes = snowflake.snowflakes
--start-module--
local _ENV = snowflake "ban"

schema {
     "guild_id"
    ,"reason"
    ,"user_id"
}

function new_from( state, payload )
    local user = payload.user
    local uid = util.uint(user.id)
    if not state.cache.user[uid] then
        snowflakes.user.new_from(state, user, state.cache.methods.user)
    end
    return setmetatable({
         uid
        ,gettime()
        ,nil
        ,payload.guild_id
        ,payload.reason or ''
        ,uid
    }, _ENV)
end

function properties.guild(ban)
    local parent = snowflakes.guild.get(ban[4])
    return parent
end

function methods.delete(ban)
    return ban.guild:unban_user(ban[6])
end

function get_from(state, guild_id, id)
    local success, data, err = api.get_guild_ban(state.api, guild_id, id)
    if success then
        data.guild_id = guild_id
        return new_from(state, data)
    else
        return nil, err
    end
end

constants.cachable = false
constants.virtual = true

--end-module--
return _ENV