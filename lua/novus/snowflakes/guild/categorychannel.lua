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
local snowflakes = snowflake.snowflakes
local running = cqueues.running
--start-module--
local _ENV = base_channel"guildcategorychannel"

local base = new_from
function new_from(state, payload)
    local object = base(_ENV, state, payload)
    object[5] = util.uint(payload.guild_id)
    object[6] = payload.name
    object[7] = payload.position
    object[8] = util.uint(payload.parent_id)
    object[11] = processor.overwrites(payload.permission_overwrites)
    return object
end

_ENV = guildchannel(modifiable(_ENV, api.method))

function methods.create_text_channel(channel, name)
    local state = running():novus()
    local success, data, err = api.create_guild_channel(channel[5], {
         name = name
        ,type = channeltype.text
        ,parent_id = channel[1]
    })
    if success then
        return snowflakes.guildtextchannel.new_from(state, data)
    else return false, err
    end
end

function methods.create_voice_channel(channel, name)
    local state = running():novus()
    local success, data, err = api.create_guild_channel(channel[5], {
         name = name
        ,type = channeltype.voice
        ,parent_id = channel[1]
    })
    if success then
        return snowflakes.guildvoicechannel.new_from(state, data)
    else return false, err
    end
end

local function select_channels(_, val, chid)
    if val.parent_id == chid then
        return val
    end
end

function properties.text_channels(channel)
    local guild = snowflakes.guild.get(channel[1])
    return view.new(guild.text_channels, select_channels, channel[1])
end

function properties.voice_channels(channel)
    local guild = snowflakes.guild.get(channel[1])
    return view.new(guild.voice_channels, select_channels, channel[1])
end

--end-module--
return _ENV