--- Guild voice channel.
-- @module novus.snowflakes.guild.voicechannel

--imports--
local api = require"novus.api"
local util = require"novus.snowflakes.helpers"
local view = require"novus.cache.view"
local snowflake = require"novus.snowflakes"
local base_channel = require"novus.snowflakes.channel"
local channeltype = require"novus.enums".channeltype
local modifiable = require"novus.snowflakes.mixins.modifiable"
local guildchannel = require"novus.snowflakes.mixins.guildchannel"
local cqueues = require"cqueues"
local null = require"cjson".null
local snowflakes = snowflake.snowflakes
local running = cqueues.running
--start-module--
local _ENV = base_channel"guildvoicechannel"
local base = new_from

_ENV = guildchannel(modifiable(_ENV, api.method))

schema{
     "bitrate"
    ,"user_limit"
}

function new_from(state, payload)
    local object = base(_ENV, state, payload)
    object[5] = util.uint(payload.guild_id)
    object[6] = payload.name
    object[7] = payload.position
    object[8] = util.uint(payload.parent_id)
    object[11] = processor.overwrites(payload.permission_overwrites)
    object[12] = payload.bitrate
    object[13] = payload.user_limit
    return object
end

function methods.set_bitrate(channel, bitrate)
    return modify(channel, {bitrate = bitrate or null})
end

function methods.set_user_limit(channel, limit)
    return modify(channel, {user_limit = limit or null})
end

local function select_members(_, vstate, chid)
    if vstate.channel_id == chid then
        return snowflakes.member.get(vstate.guild_id, vstate.user_id)
    end
end

function properties.connected_members(channel)
    return view.new(channel.guild.voice_states, select_members, channel[1])
end

--end-module--
return _ENV