--- Discord enumerations.
-- Dependencies: `util`
-- Please refer to the [discord api documentation](https://discordapp.com/developers/docs/intro) for specific information.
-- @module enums
-- @alias _ENV

--imports--
local util = require"novus.util"
local require = require
local setmetatable = setmetatable
local pairs = pairs
local pcall = pcall

--start-module--
local _ENV = {}

local function make_enum(tbl)
    local new = {}
    for key, value in pairs(tbl) do
        new[key], new[value] = value, key
    end
    return new
end

local function enum_loader(name)
    local success, M = pcall(require, name)
    if success then
        return make_enum(M)
    else
        return nil, M
    end
end

setmetatable(_ENV, _ENV)

function __index(self, key)
    local lookup = key:lower()
    local enum, err = enum_loader(("novus.enums.%s"):format(lookup))
    if enum then
        self[key] = enum
        return enum
    else
        util.throw("%s", err or '')
    end
end

--- Game activity types.
-- @table activitytype
-- @within Enumerations
-- @int default 0
-- @int streaming 1
-- @int listening 2

--- Audit log entry event types.
-- See [here](https://discordapp.com/developers/docs/resources/audit-log#audit-log-entry-object-audit-log-events).
-- @table auditlogtype
-- @within Enumerations

--- Channel types.
-- @table channeltype
-- @within Enumerations
-- @int text 0
-- @int private 1
-- @int voice 2
-- @int group 3
-- @int category 4

--- Default avatar types.
-- @table defaultavatartype
-- @within Enumerations
-- @int blurple 0
-- @int grey 1
-- @int green 2
-- @int orange 3
-- @int red 4


--- Explicit content levels.
-- @table explicitcontentlevel
-- @within Enumerations
-- @int none 0
-- @int medium 1
-- @int high 2

--- Message types.
-- @table messagetype
-- @within Enumerations
-- @int default 0
-- @int recipientAdd 1
-- @int recipientRemove 2
-- @int call 3
-- @int channelNameChange 4
-- @int channelIconchange 5
-- @int pinnedMessage 6
-- @int memberJoin 7

--- Status types.
-- @table statustype
-- @within Enumerations
-- @string online "online"
-- @string idle "idle"
-- @string donotdisturb "dnd"
-- @string invisible "invisible"

--- Verification levels.
-- @table verificationlevel
-- @within Enumerations
-- @int none 0
-- @int low 1
-- @int medium 2
-- @int high 3
-- @int veryhigh 4


--end-module--
return _ENV