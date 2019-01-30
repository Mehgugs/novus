--imports--
local api = require"novus.api"
local util = require"novus.snowflakes.helpers"
local snowflake = require"novus.snowflakes.snowflake"
local cqueues = require"cqueues"
local channel_type = require"novus.enums".channeltype
local setmetatable = setmetatable
local gettime = cqueues.monotime
local running = cqueues.running
local snowflakes = snowflake.snowflakes
--start-module--
local _ENV = snowflake"channel"

schema {
     "type" --4
}

function new_from(_ENV, state, payload, cache) --luacheck: ignore
    return setmetatable({
         util.uint(payload.id)
        ,gettime()
        ,cache
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

function get_from(state, channel_id, id)
    local mcache = state.cache.channel[channel_id]
    if mcache[id] then return mcache[id]
    else
        local success, data, err = api.get_message(state.api, channel_id, id)
        if success then
            return snowflakes[snowflake_map[channel_type[data.type]]].new_from(state, data)
        else
            return nil, err
        end
    end
end

--end-module--
return _ENV