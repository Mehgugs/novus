--imports--
local api = require"novus.api"
local util = require"novus.snowflakes.helpers"
local list = require"novus.util.list"
local snowflake = require"novus.snowflakes"
local textchannel = require"novus.snowflakes.channel.textchannel"
local setmetatable = setmetatable
--start-module--
local _ENV = textchannel"privatechannel"

schema{
    "recipient_id"
}

function new_from(state, data)
    local object = textchannel.newer_from(_ENV, state, data)
    local user = data.recipients[1]
    local uid = util.uint(user.id)
    if not state.cache.user[uid] then
        snowflakes.user.new_from(state, user)
    end
    object.recipient_id = uid
    return object
end

function methods.close(channel)
    return channel:delete()
end

function properties.recipient(channel)
    return snowflakes.user.get(channel.recipient_id)
end

constants.abstract = false

--end-module--
return _ENV