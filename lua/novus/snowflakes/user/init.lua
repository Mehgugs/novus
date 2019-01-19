--imports--
local util = require"novus.snowflakes.helpers"
local snowflake = require"novus.snowflakes.snowflake"
local const = require"novus.const"
local api = require"novus.api"
local cqueues = require"cqueues"
local setmetatable = setmetatable
local gettime = cqueues.monotime
local running = cqueues.running
--start-module--
local _ENV = snowflake "user"

schema { 
     "username" --4
    ,"discriminator" --5
    ,"avatar" --6
    ,"bot"
    ,"mfa_enabled"
    ,"verified"
    ,"email"
}

function new_from(state, payload, cache)
    return setmetatable({
         util.uint(payload.id)
        ,gettime() 
        ,cache
        ,payload.username
        ,payload.discriminator
        ,payload.avatar
        ,not not payload.bot 
        ,not not payload.mfa_enabled
    }, _ENV)
end

function new(...) return new_from(_, ...) end

function email_scope(user, payload)
    user[9] = not not payload.verified
    user[10] = payload.email or ''
    return user
end

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

function methods.default_avatar(user, size)
    local id = user[5] % const.default_avatars
    local unsized = const.api.default_avatar_endpoint:format(id)
    if size then 
        return ("%s?size=%d"):format(unsized, size)
    else return unsized 
    end 
end

function methods.private_channel(user)
    local channel, err = snowflakes.private_channel.get(user[1])
    return channel, err
end

function methods.dm(user, ...)
    local channel, err = methods.private_channel(user)
    if channel then 
        return channel:send(...)
    else 
        return nil, err
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
        local cacher = state.cache.methods[__name]
        local success, data, err = api.get_user(state.api, id)
        if success then
            return new(data, cacher)
        else 
            return nil, err 
        end
    end
end

--end-module--
return _ENV