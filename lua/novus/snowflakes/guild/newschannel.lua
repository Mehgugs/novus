--imports--
local textchannel = require"novus.snowflakes.guild.textchannel"
--start-module--
local _ENV = textchannel"guildnewschannel"

local base = textchannel.new_from
function new_from(state, payload)
    local object = base(state, payload)
    object.ratelimit_per_user = 0
    return object
end

--end-module--
return _ENV