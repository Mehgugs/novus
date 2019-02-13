--imports--
local api = require"novus.api"
local util = require"novus.snowflakes.helpers"
local cache = require"novus.cache"
local snowflake = require"novus.snowflakes"
local modifiable = require"novus.snowflakes.mixins.modifiable"
local reaction = require"novus.snowflakes.channel.reaction"
local view = require"novus.cache.view"
local cqueues = require"cqueues"
local json = require"cjson"
local null = json.null
local running = cqueues.running
local setmetatable = setmetatable
local gettime = cqueues.monotime
local snowflakes = snowflake.snowflakes
local patterns = util.patterns
local ipairs = ipairs
local insert = table.insert
local includes = util.includes
local getmetatable = getmetatable
local type = type
--start-module--
local _ENV = snowflake "message"
--[[
    id	snowflake	id of the message
    channel_id	snowflake	id of the channel the message was sent in
    guild_id?	snowflake	id of the guild the message was sent in
    author*	user object	the author of this message (not guaranteed to be a valid user, see below)
    member?	partial guild member object	member properties for this message's author
    content	string	contents of the message
    timestamp	ISO8601 timestamp	when this message was sent
    edited_timestamp	?ISO8601 timestamp	when this message was edited (or null if never)
    tts	boolean	whether this was a TTS message
    mention_everyone	boolean	whether this message mentions everyone
    mentions	array of user objects, with an additional partial member field	users specifically mentioned in the message
    mention_roles	array of role object ids	roles specifically mentioned in this message
    attachments	array of attachment objects	any attached files
    embeds	array of embed objects	any embedded content
    reactions?	array of reaction objects	reactions to the message
    nonce?	?snowflake	used for validating a message was sent
    pinned	boolean	whether this message is pinned
    webhook_id?	snowflake	if the message is generated by a webhook, this is the webhook's id
    type	integer	type of message
    activity?	message activity object	sent with Rich Presence-related chat embeds
    application?	message application object	sent with Rich Presence-related chat embeds
]]
schema {
     "channel_id" --4
    ,"guild_id" -- 5
    ,"author_id" --6
    ,"type" -- 7
    ,"content" -- 8
    ,"timestamp" --9
    ,"edited_timestamp" -- 10
    ,"tts" -- 11
    ,"attachments" -- 12
    ,"embeds" -- 13
    ,"nonce" -- 14
    ,"pinned" -- 15

    ,"mention_everyone" -- 16
    ,"mentions" -- 17
    ,"mention_roles" -- 18

    ,"reactions" -- 19

    ,"webhook_id" -- 20

    ,"activity" -- 21
    ,"application" -- 22
    ,"mentioned"
}

function processor.mentions(payload, state)
    local mentions = {}
    if payload.mentions then
        for i, u in ipairs(payload.mentions) do
            local uid = util.uint(u.id)
            if not state.cache.user[uid] then
                snowflakes.user.new_from(state, u, state.cache.methods.user)
            end
            mentions[i] = uid
        end
    end
    return mentions
end

function processor.reactions(payload, state)
    local out = {}
    if payload.reactions then
        out = {}
        for _, r in ipairs(payload.reactions) do
            local new = reaction.new_from(state, r)
            out[new.emoji_id] = new
        end
    end
    return out
end

function processor.author(payload, state)
    local user = payload.author
    if user then
        local uid = util.uint(user.id)
        if not state.cache.user[uid] then
            snowflakes.user.new_from(state, user, state.cache.methods.user)
        end
        return uid
    end
end

function new_from(state, payload)
    local channel_id, guild_id =
     util.uint(payload.channel_id)
    ,util.uint(payload.guild_id)
    if state.options.cache_messages then
        local mycache = state.cache.message[channel_id]
        local method = state.cache.methods.message[channel_id]
        if mycache == nil then
            mycache = util.cache()
            state.cache.message[channel_id] = mycache
            method = cache.inserter(mycache)
            state.cache.methods.message[channel_id] = method
        end
    end

    return setmetatable({
        util.uint(payload.id)
        ,gettime()
        ,method
        ,channel_id
        ,guild_id
        ,processor.author(payload, state)
        ,payload.type
        ,payload.content
        ,payload.timestamp
        ,payload.edited_timestamp
        ,payload.tts
        ,payload.attachments
        ,payload.embeds
        ,payload.nonce
        ,payload.pinned

        ,payload.mention_everyone
        ,processor.mentions(payload, state)
        ,payload.mention_roles

        ,processor.reactions(payload, state)

        ,payload.webhook_id

    },_ENV)
end

_ENV = modifiable(_ENV, api.edit_message) -- endow with modify

function methods.edit(message, arg, ...)
    local content = null
    if type(arg) == 'string' then
        content = arg:format(...)
    end

    return modify(message, {content = content})
end

function methods.edit_embed(message, embed)
    local content = null
    if type(embed) == 'table' then
        content = embed
    end
    return modify(message, {embed = content})
end

function methods.pin(message)
    local state = running():novus()
    local success, data, err = api.add_pinned_channel_message(state.api, message[4], message[1])
    if success and data then
        message[15] = true
        return true
    else
        return false, err
    end
end

function methods.unpin(message)
    local state = running():novus()
    local success, data, err = api.delete_pinned_channel_message(state.api, message[4], message[1])
    if success and data then
        message[15] = false
        return true
    else
        return false, err
    end
end

function methods.add_reaction(message, emoji)
    local typ = getmetatable(emoji)
    if typ and typ == snowflakes.emoji then
        emoji = emoji.nonce
    elseif typ and typ == snowflakes.reaction then
        return methods.add_reaction(message, emoji.emoji)
    elseif type(emoji) ~= 'string' then
        return false
    end
    local state = running():novus()
    local success, data, err = api.create_reaction(state.api, message[4], message[1], emoji)
    if success and data then
        return true
    else
        return false, err
    end
end


function methods.remove_reaction(message, emoji, user)
    local typ = getmetatable(emoji)
    if typ and typ == snowflakes.emoji then
        emoji = emoji.nonce
    elseif typ and typ == snowflakes.reaction then
        return methods.add_reaction(message, emoji.emoji, user)
    elseif type(emoji) ~= 'string' then
        return false
    end
    local state = running():novus()
    local id = snowflake.id(user)
    local success, data, err
    if id then
        success, data, err = api.delete_user_reaction(state.api, message[4], message[1], emoji, id)
    else
        success, data, err = api.delete_own_reaction(state.api, message[4], message[1], emoji)
    end
    if success and data then
        return true
    else
        return false, err
    end
end

function methods.remove_all_reactions(message)
    local state = running():novus()
    local success, data, err = api.delete_all_reactions(state.api, message[4], message[1])
    if success and data then
        return true
    else
        return false, err
    end
end

function methods.delete(message)
    local state = running():novus()
    local success, data, err = api.delete_message(state.api, message[4], message[1])
    if success and data then
        local channel = snowflakes.channel.get_from(state, message[4])
        channel[6] = view.remove(channel[6], message[1])
        return true
    else
        return false, err
    end
end

function methods.reply(message, ...)
    local channel = snowflakes.channel.get(message[4])
    return channel:send(...)
end

local function get_mentions(key, value, set)
    return includes(set, key) and value
end

function properties.full_mentions(message)
    return view.from(running():novus().cache.user, get_mentions, message[17])
end

local function get_reactions(_, id)
    return snowflakes.reaction.get(id)
end

function properties.full_reactions(message)
    return view.from(message[19], get_reactions)
end

local imt = {}
imt.__call = ipairs
local function iiter(t)
    return setmetatable(t, imt)
end

function properties.mentioned(message)
    local new = iiter{}
    for pos, m in patterns.mentions(message[8]) do
        m.position = pos
        local name = m.type .. 's'
        new[name] = new[name] or iiter{}
        insert(new, m)
        insert(new[name], m)
    end
    message[23] = new
    return new
end

function properties.author(message)
    return message[6] and snowflakes.user.get(message[6])
end

function properties.channel(message)
    return snowflakes.channel.get(message[4])
end

function properties.guild(message)
    return message[5] and snowflakes.guild.get(message[5])
end

function properties.member(message)
    return message[5] and snowflakes.member.get(message[5], message[6])
end

function properties.link(message)
    return "https://discordapp.com/channels/%s/%s/%s" % {
         message[5] or '@me'
        ,message[4]
        ,message[1]
    }
end

function get_from(state, channel_id, id)
    local mcache = state.cache.message[channel_id]
    if mcache and mcache[id] then return mcache[id]
    else
        local success, data, err = api.get_channel_message(state.api, channel_id, id)
        if success then
            return new_from(state, data)
        else
            return nil, err
        end
    end
end

function destroy_from(state, msg)
    state.cache.message[msg.channel_id][msg.id] = nil
    if msg.cache then
        msg.cache = nil
    end
end



--end-module--
return _ENV