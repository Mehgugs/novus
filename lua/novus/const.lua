--start-module--
local _ENV = {}

version = "0.0.1"
homepage = "https://github.com/Mehgugs/novus"
time_unit = "seconds"
discord_epoch = 1420070400
gateway_delay = .5
identify_delay = 5

api = {
    baseEndpoint = "https://discordapp.com/api",
    version = 6,
}
api.endpoint = ("%s/v%s"):format(api.baseEndpoint, api.version)

--end-module--
return _ENV