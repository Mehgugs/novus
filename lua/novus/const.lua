local setmetatable = setmetatable
--start-module--
local _ENV = {}

version = "0.0.2"
homepage = "https://github.com/Mehgugs/novus"
time_unit = "seconds"
discord_epoch = 1420070400
gateway_delay = .5
identify_delay = 5

api = {
     base_endpoint = "https://discordapp.com/api"
    ,avatar_endpoint = "https://cdn.discordapp.com/avatars/%s/%s.%s"
    ,default_avatar_endpoint = "https://cdn.discordapp.com/embed/avatars/%s.png"
    ,emoji_endpoint = "https://cdn.discordapp.com/emojis/%s.%s"
    ,version = 6
}
api.endpoint = ("%s/v%s"):format(api.base_endpoint, api.version)

default_avatars = 5

lifetimes = setmetatable({}, {__index = function(l) return l.default end})

lifetimes.default = 1.0

--end-module--
return _ENV