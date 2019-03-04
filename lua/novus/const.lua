--- Constant values.
-- @module const
-- @alias _ENV

--- The novus library version string.
-- @string version
-- @within Constants

--- The novus library homepage.
-- @string homepage
-- @within Constants

--- The gateway and api version the library is connecting to.
-- @int api_version
-- @within Constants

--- The cache lifetimes for kinds of snowflakes.
-- @table lifetimes
-- @number default The default lifetime.
-- @within Constants

local setmetatable = setmetatable
--start-module--
local _ENV = {}

version = "0.0.6"
homepage = "https://github.com/Mehgugs/novus"
time_unit = "seconds"
discord_epoch = 1420070400
gateway_delay = .5
identify_delay = 5
api_version = 7

api = {
     base_endpoint = "https://discordapp.com/api"
    ,avatar_endpoint = "https://cdn.discordapp.com/avatars/%u/%s.%s"
    ,default_avatar_endpoint = "https://cdn.discordapp.com/embed/avatars/%s.png"
    ,emoji_endpoint = "https://cdn.discordapp.com/emojis/%s.%s"
    ,icon_endpoint = "https://cdn.discordapp.com/icons/%s/%s.png"
    ,splash_endpoint = "https://cdn.discordapp.com/splashs/%s/%s.png"
    ,version = api_version
    ,max_retries = 6
}
gateway = {
     delay = .5
    ,identify_delay = 5
    ,version = api_version
    ,encoding = "json"
    ,compress = "zlib-stream"
}
api.endpoint = ("%s/v%s"):format(api.base_endpoint, api.version)

default_avatars = 5

lifetimes = setmetatable({}, {__index = function(l) return l.default end})

lifetimes.default = 60 * 60
lifetimes.guild = -1
lifetimes.message = 0

--end-module--
return _ENV