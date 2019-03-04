--- private channel snowflake definition.
--  Dependencies: `snowflakes`, `textchannel`, `novus.api`, `novus.list`.
--  @module snowflakes.privatechannel
--  @alias privatechannel

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

--- A discord private channel object.
--  Inherits from `snowflakes.textchannel`
-- @table privatechannel
-- @within Objects
-- @int id
-- @tparam number life
-- @tparam function cache
-- @tparam integer type See @{novus.enums.channeltype|channel types}
-- @tparam integer last_message_id
-- @tparam view messages
-- @tparam integer recipient_id

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

--- Closes the direct message channel.
--  Alias to @{snowflakes.channel.delete|`channel:delete()`}.
--  @function channel.close
--  @within Methods
--  @tparam privatechannel channel
--  @treturn[1] boolean true
--  @treturn[2] nil
--  @treturn[2] string error string
function methods.close(channel)
    return channel:delete()
end

function properties.recipient(channel)
    return snowflakes.user.get(channel.recipient_id)
end

--- The recipient of the DM.
--  @tparam user recipient
--  @within Properties

constants.abstract = false

--end-module--
return _ENV