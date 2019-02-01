--imports--
local api = require"novus.api"
local util = require"novus.snowflakes.helpers"
local list = require"novus.util.list"
local snowflake = require"novus.snowflakes.snowflake"
local textchannel = require"novus.snowflakes.channel.textchannel"
local modifiable = require"novus.snowflakes.mixins.modifiable"
local guildchannel = require"novus.snowflakes.mixins.guildchannel"
local cqueues = require"cqueues"
local json = require"cjson"
local null = json.null

local running = cqueues.running
local snowflakes = snowflake.snowflakes

local ipairs = ipairs

--start-module--
local _ENV = textchannel"guildtextchannel"

function new_from(state, payload)
    local object = textchannel.new_from(_ENV, state, payload)
    object[7] = util.uint(payload.guild_id)
    object[8] = payload.name
    object[9] = payload.position
    object[10] = util.uint(payload.parent_id)
    object[11] = processor.overwrites(payload.permission_overwrites)
    return object
end

_ENV = guildchannel(modifiable(_ENV, api.modify_channel)) --endow common guild channel methods

function methods.create_webhook(channel, name)
    local state = running():novus()
    local success, data, err = api.create_webhook(state.api, channel[1], {name = name})
    if success then
        return snowflakes.webhook.new_from(state, data)
    else
        return false, err
    end
end

local function new_webhook(w, state)
    return snowflakes.webhook.new_from(state, w)
end

function methods.get_webhooks(channel)
    local state = running():novus()
    local success, data, err = api.get_channel_webhooks(state.api, channel[1])
    if success then
        return list.map(new_webhook, data)
    else
        return false, err
    end
end

function methods.prune(channel, msg_or_msgs)
    local state = running():novus()
    local success, _, err
    if snowflake.id(msg_or_msgs) then
        success, _, err = api.delete_message(state.api, channel[1], snowflake.id(msg_or_msgs))
    else
        local msgs = list.map(snowflake.id, msg_or_msgs)
        success, _, err = api.bulk_delete_messages(state.api, channel[1], msgs)
    end
    if success then
        return true
    else
        return false, err
    end
end

function methods.set_topic(channel, topic)
    return modify(channel, {topic = topic or null})
end

function methods.set_ratelimit(channel, limit)
    return modify(channel, {rate_limit_per_user = limit or null})
end

function methods.set_nsfw(channel)
    return modify(channel, {nsfw = true})
end

function methods.set_sfw(channel)
    return modify(channel, {nsfw = false})
end

local function select_members(_, member, chid)
    if member:get_permissions(chid):contains'readMessages' then
        return member
    end
end

function properties.members(channel)
    local state = running():novus()
    return view.new(state.cache.member, select_members, channel[1])
end

function properties.guild(channel)
    return snowflakes.guild.get(channel[7])
end

function properties.category(channel)
    if channel[10] then
        return snowflakes.channel.get(channel[10])
    end
end



--end-module--
return _ENV