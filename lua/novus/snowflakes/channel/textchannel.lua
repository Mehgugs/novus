--- Abstract text channel snowflake definition.
--  Dependencies: `snowflakes`, `channel`, `novus.api`, `novus.cache`, `novus.cache.view`.
--  @module snowflakes.textchannel
--  @alias textchannel

--imports--
local util = require"novus.snowflakes.helpers"
local cache = require"novus.cache"
local snowflake = require"novus.snowflakes"
local cqueues = require"cqueues"
local view = require"novus.cache.view"
local api = require"novus.api"
local base_channel = require"novus.snowflakes.channel"
local running = cqueues.running
local setmetatable = setmetatable
local snowflakes = snowflake.snowflakes
local type = type
local ipairs = ipairs
local insert, concat = table.insert, table.concat
local tostring = tostring
--start-module--
local _ENV =  base_channel("textchannel")

schema {
     "last_message_id" --5
    ,"messages" --6
}

--- An abstract text channel object.
--  Inherits from `snowflakes.channel`
-- @table textchannel
-- @within Objects
-- @int id
-- @tparam number life
-- @tparam function cache
-- @tparam integer type See @{novus.enums.channeltype|channel types}
-- @tparam integer last_message_id
-- @tparam view messages

local base = base_channel.newer_from
function newer_from(_ENV, state, payload) --luacheck: ignore
    local object = base(_ENV, state, payload, cache)
    object[5] = util.uint(payload.last_message_id)

    state.cache.message[object[1]] =
        state.cache.message[object[1]]
    or  cache.new()

    state.cache.methods.message[object[1]] =
        state.cache.methods.message[object[1]]
    or  cache.inserter(state.cache.message[object[1]])

    object[6] = view.copy(state.cache.message[object[1]])

    return object
end

function methods.get_message(channel, id)
    return snowflakes.message.get_from(running():novus(), channel[1], id)
end

function methods.first_message(channel)
    local state = running():novus()
    local success, data, err = api.get_channel_messages(state.api, channel[1], {after = channel[1], limit = 1})
    if success and data[1] then
        return snowflakes.message.new_from(state, data[1])
    elseif success and data[1] == nil then
        return false, "Channel has no messages."
    else
        return success, err
    end
end

function methods.last_message(channel)
    local state = running():novus()
    local success, data, err = api.get_channel_messages(state.api, channel[1], {limit = 1})
    if success and data[1] then
        return snowflakes.message.new_from(state, data[1])
    elseif success and data[1] == nil then
        return false, "Channel has no messages."
    else
        return success, err
    end
end

local function get_messages(channel, query)
    local state = running():novus()
    local success, data, err = api.get_channel_messages(state.api, channel[1], query)
    if success then
        return data
    else
        return false, err
    end
end

function methods.get_messages(channel, limit)
    return get_messages(channel, limit and {limit = limit})
end

function methods.get_after(channel, id, limit)
    id = snowflake.id(id)
    return id and get_messages(channel, {after = id, limit = limit or 1})
end

function methods.get_before(channel, id, limit)
    id = snowflake.id(id)
    return id and get_messages(channel, {before = id, limit = limit or 1})
end

function methods.get_around(channel, id, limit)
    id = snowflake.id(id)
    return id and get_messages(channel, {around = id, limit = limit or 1})
end

function methods.pinned_mesages(channel)
    local state = running():novus()
    local success, data, err = api.get_pinned_messages(state.api, channel[1])
    if success then
        local chid = channel[1]
        return setmetatable({}, {__index = function(t, i)
            local m = snowflakes.message.get(chid, data[i])
            t[i] = m
            return m
        end})
    else
        return false, err
    end
end

function methods.broadcast_typing(channel)
    local state = running():novus()
    local success, data, err = api.trigger_typing_indicator(state.api, channel[1])
    if success and data then
        return true
    else
        return false, err
    end
end

--- Sends a message to the channel.
--  @function textchannel.send
--  @within Methods
--  @tparam textchannel channel
--  @tparam string|table content Either a formattable string, or an options table.
--  @param  ... Format parameters to the format string.
--  @treturn[1] message
--  @treturn[2] nil
--  @treturn[2] string error message
function methods.send(channel, content, ...)
    local state = running():novus()
    local success, data, err
    if type(content) == 'table' then
        local payload = content
        content = payload.content
        local mentions = {}
        if payload.mention then
            payload.mentions = payload.mentions or {}
            insert(payload.mentions, payload.mention)
        end
        if payload.mentions then
            for _ , m in ipairs(payload.mentions) do
                if type(m) == 'table' and m[snowflake] and m.mention then
                    insert(mentions, m.mention)
                else
                    return util.throw("%s was not a mentionable object!", tostring(m) or 'nil')
                end
            end
        end
        if content then
            content = concat(mentions, "") .. content
        end
        success, data, err = api.create_message(state.api, channel[1], {
             content = content
            ,tts = payload.tts
            ,nonce = payload.nonce
            ,embed = payload.embed
        }, payload.files)
    else
        success, data, err =  api.create_message(state.api, channel[1], {
            content = content:format(...)
        })
    end
    if success and data then
        return snowflakes.message.new_from(state, data)
    else
        return false, err
    end
end

--- `textchannel.send` options.
--   @table send_options
--   @within Objects
--   @see textchannel.send
--   @tparam string content The content to send.
--   @tparam snowflakes.snowflake|nil mention A mentionable discord object.
--   @tparam table(snowflakes.snowflake)|nil mentions A list of mentionable discord objects.
--   @tab embed A table describing a discord embed.
--   @tparam boolean tts Whether the message is `tts`.
--   @tab files A list of `{name, content}` pairs to send as attached files.

--end-module--
return _ENV