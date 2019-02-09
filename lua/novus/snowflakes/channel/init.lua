--imports--
local api = require"novus.api"
local util = require"novus.snowflakes.helpers"
local snowflake = require"novus.snowflakes"
local cqueues = require"cqueues"
local channel_type = require"novus.enums".channeltype
local setmetatable = setmetatable
local gettime = cqueues.monotime
local running = cqueues.running
local snowflakes = snowflake.snowflakes
local pretty = require"pl.pretty"
--start-module--
local _ENV = snowflake"channel"

schema {
     "type" --4
}

function newer_from(_ENV, state, payload) --luacheck: ignore
    return setmetatable({
         util.uint(payload.id)
        ,gettime()
        ,state.cache.methods.channel
        ,payload.type
    }, _ENV)
end

function methods.delete(channel)
    local state = running():novus()
    local success, data, err = api.delete_channel(state.api, channel[1])
    if success and data then
        return true
    else
        return false, err
    end
end

constants.abstract = true

local snowflake_map = {
     text = 'guildtextchannel'
    ,private = 'privatetextchannel'
    ,voice = 'guildvoicechannel'
    ,category = 'guildcategorychannel'
    ,group = 'groupchannel'
}

function get_from(state, channel_id)
    if state.cache.channel[channel_id] then return state.cache.channel[channel_id]
    else
        local success, data, err = api.get_channel(state.api, channel_id)
        if success then
            return snowflakes[snowflake_map[channel_type[data.type]]].new_from(state, data)
        else
            return nil, err
        end
    end
end

function new_from(state, payload, old)
    local typ = snowflakes[snowflake_map[channel_type[payload.type]]]
    return typ.new_from(state, payload, old)
end

--end-module--
return _ENV