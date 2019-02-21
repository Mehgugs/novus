--imports--
local snowflake = require"novus.snowflakes"
local gettime = require"cqueues".monotime
local null = require"cjson".null
local setmetatable = setmetatable
local snowflakes = snowflake.snowflakes
local codepoint = utf8.codepoint
local uchar = utf8.char

--start-module--
local _ENV = snowflake "reaction"

schema {
     "me"
    ,"count"
    ,"emoji_id"
    ,"custom"
}

function processor.emoji(payload, state)
    if payload.emoji.id ~= null then
        return snowflakes.emoji.new_from(state, payload.emoji) , "emoji_id"
    else
        return codepoint(payload.emoji.name) , "emoji_id"
    end
end

function new_from(state, payload)
    return setmetatable({
         nil
        ,gettime()
        ,nil
        ,payload.me
        ,payload.count
        ,processor.emoji(payload, state)
        ,payload.emoji.id ~= null
    }, _ENV)
end

function properties.emoji(reaction)
    if reaction.custom then return snowflakes.emoji.get(reaction.emoji_id)
    else return uchar(reaction.emoji_id)
    end
end

__gc = nil

constants.virtual = true
--end-module--
return _ENV