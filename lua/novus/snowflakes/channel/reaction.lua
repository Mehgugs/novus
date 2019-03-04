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
    ,"name"
}

function processor.emoji(payload, state)
    if payload.emoji.id ~= null then
        snowflakes.emoji.upsert(state, payload.emoji)
        return payload.emoji.id, "emoji_id"
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
        ,payload.emoji.name
    }, _ENV)
end

function properties.emoji(reaction)
    if reaction.custom then return snowflakes.emoji.get(reaction.emoji_id)
    else return uchar(reaction.emoji_id)
    end
end

function properties.nonce(reaction)
    if reaction.custom then return "%s:%s" % {reaction.name, reaction.emoji_id}
    else return uchar(reaction.emoji_id)
    end
end

__gc = nil

constants.virtual = true
--end-module--
return _ENV