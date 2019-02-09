--imports--
local util = require"novus.snowflakes.helpers"
local snowflake = require"novus.snowflakes"
local action_types = require"novus.enums".auditlogtype
local setmetatable = setmetatable
local snowflakes = snowflake.snowflakes
--start-module--
local _ENV = snowflake "auditlog_entry"

schema {
     "target_id"
    ,"changes"
    ,"user_id"
    ,"action_type"
    ,"options"
    ,"reason"
}

function new_from(state, payload)
    --_ENV[action_types[payload.action_type]](state, payload) TODO
    return setmetatable({
         util.uint(payload.id)
        ,gettime()
        ,nil
        ,payload.target_id
        ,payload.changes or {}
        ,payload.user_id
        ,payload.action_type
        ,payload.options or {}
        ,payload.reason or ''
    }, _ENV)
end

function GUILD_UPDATE(state, payload)
end

constants.cachable = false
constants.virtual = false

--end-module--
return _ENV