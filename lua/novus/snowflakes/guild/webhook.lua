--imports--
local cqueues = require"cqueues"
local api = require"novus.api"
local const = require"novus.const"
local util = require"novus.snowflakes.helpers"
local snowflake = require"novus.snowflakes"
local modifiable = require"novus.snowflakes.mixins.modifiable"
local null = require"cjson".null
local setmetatable = setmetatable
local snowflakes = snowflake.snowflakes
local running = cqueues.running
local gettime = cqueues.monotime
--start-module--
local _ENV = snowflake "webhook"

schema {
     "channel_id" --4
    ,"name" --5
    ,"avatar" --6
    ,"token" --7
    ,"guild_id" --8
    ,"user_id" --9
}

function new_from(state, payload)
    local user = payload.user
    local uid = user and util.uint(user.id)
    if uid and not state.cache.user[uid] then
        snowflakes.user.new_from(state, user)
    end
    return setmetatable({
         util.uint(payload.id)
        ,gettime()
        ,nil
        ,util.uint(payload.channel_id)
        ,payload.name
        ,payload.avatar
        ,payload.token
        ,util.uint(payload.guild_id)
        ,uid
    }, _ENV)
end

_ENV = modifiable(_ENV, api.modify_webhook)

function processor.user(user)
    local uid = user and util.uint(user.id)
    local state = running():novus()
    if uid and not state.cache.user[uid] then
        snowflakes.user.new_from(state, user)
    end
    return uid, 9
end

function methods.avatar_url(webhook, size, ext)
    if webhook[6] then
        ext = ext or webhook[6]:startswith"_a" and 'gif' or 'png'
        local unsized = const.api.avatar_endpoint:format(webhook[1], webhook[6], ext)
        if size then
            return ("%s?size=%d"):format(unsized, size)
        else return unsized
        end
    else return methods.default_avatar(nil, size)
    end
end

function methods.default_avatar(_, size)
    local unsized = const.api.default_avatar_endpoint:format(0)
    if size then
        return ("%s?size=%d"):format(unsized, size)
    else return unsized
    end
end

function methods.set_name(webhook, name)
    return modify(webhook, {name = name or null})
end


function methods.set_avatar(webhook, avatar)
    return modify(webhook, {name = avatar or null})
end

function methods.delete(webhook)
    local state = running():novus()
    local success, _, err = api.delete_webhook(state.api, webhook[1])
    if success then
        return true
    else
        return false, err
    end
end

constants.cachable = false

--end-module--
return _ENV