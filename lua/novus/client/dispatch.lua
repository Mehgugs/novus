--imports--
local interposable = require"novus.client.interposable"
local cond = require"cqueues.condition"
local promise = require"cqueues.promise"
local util = require"novus.util"
local list = require"novus.util.list"
local view = require"novus.cache.view"
local enums = require"novus.enums"
local const = require"novus.const"
local ctx = require"novus.client.context"
local concat = table.concat

local snowflake = require"novus.snowflakes"

local user = require"novus.snowflakes.user"

local guild = require"novus.snowflakes.guild"
    local member = require"novus.snowflakes.guild.member"
    local emoji  = require"novus.snowflakes.guild.emoji"
    local role   = require"novus.snowflakes.guild.role"
local channel = require"novus.snowflakes.channel"
local dm = require"novus.snowflakes.channel.privatechannel"
    local message  = require"novus.snowflakes.channel.message"
    local reaction = require"novus.snowflakes.channel.reaction"

local assert = assert
local ipairs = ipairs
local insert = table.insert
local function select_dms(_, chan)
    return chan.type == enums.channeltype.private and chan or nil
end



--start-module--
local _ENV = interposable{}

function READY(client, shard, _, event)
    util.info"READY"
    if event.v ~= const.gateway.version then
        return util.fatal("Gateway responded with an incorrect version: %s", event.v)
    end
    shard.session_id = event.session_id
    user.upsert(client, event.user)

    for _, chan in ipairs(event.private_channels) do
        if chan.type == enums.channeltype.private then
            dm.upsert(client, chan)
        end
    end

    client.dms = view.new(client.cache.channel, select_dms)

    shard.to_load = #event.guilds
    shard.loading = 0
    for _, g in ipairs(event.guilds) do
        g.id = util.uint(g.id)
        guild.upsert(client, g)
    end
    if shard.raw_ready:status() == "pending" then shard.raw_ready:set(true, true) end
    return client.events.SHARD_READY:emit(ctx{shard = shard.options.id})
end

function RESUMED(client, shard, _, event)
    util.info("Shard-%s has resumed trace=%q", shard.options.id, concat(event._trace, ', '))
    return client.events.RESUMED:emit(ctx{shard = shard.options.id})
end

local function load_members(m, _, state, gid)
    m.guild_id = gid
    member.upsert(state, m, gid)
end

function GUILD_MEMBERS_CHUNK(client, shard, _, event)
    event.guild_id = util.uint(event.guild_id)
    return list.each(load_members, event.members, client, event.guild_id)
end

function CHANNEL_CREATE(client, shard, _, event)
    local has_guild = enums.channeltype[event.type]:startswith"guild"
    local g
    event.guild_id = util.uint(event.guild_id)
    if has_guild then
        g = guild.get_from(client, event.guild_id)
    end
    return client.events.CHANNEL_CREATE:emit(ctx(g, channel.upsert(client, event)))
end

function CHANNEL_UPDATE(client, shard, _, event)
    local g
    event.guild_id = util.uint(event.guild_id)
    if event.guild_id then
        g = guild.get_from(client, event.guild_id)
    end
    local c = channel.get_from(client, util.uint(event.id))
    channel.update_from(client, c, event)
    return client.events.CHANNEL_UPDATE:emit(ctx(g, c))
end

function CHANNEL_DELETE(client, shard, _, event)
    event.id = util.uint(event.id)
    event.guild_id = util.uint(event.guild_id)
    local channel = client.cache.channel[event.id]
    local has_guild = enums.channeltype[event.type]:startswith"guild"
    local g

    if has_guild then
        g = guild.get_from(client, event.guild_id)
        guild.remove_channel(g, event.id)
    end

    if channel then
        snowflake.destroy(channel)
        return client.events.CHANNEL_DELETE:emit(ctx(g, channel))
    else
        return client.events.CHANNEL_DELETE:emit(ctx{uncached = true, g, event})
    end
end

function GUILD_CREATE(client, shard, _, event)
    shard.raw_ready:get()
    event.id = util.uint(event.id)
    local g = client.cache.guild[event.id]
    local was_unavailable = g and g.unavailable
    local new = guild.new_from(client, event)
    if g then
        shard.loading = shard.loading + 1
        shard.to_load = shard.to_load - 1
        if was_unavailable and not event.unavailable then
            client.events.GUILD_AVAILABLE:emit(ctx(new))
        end
        util.warn("%s loaded - %s left", shard.loading, shard.to_load)
        if shard.to_load == 0 and shard.is_ready:status() == 'pending' then
            shard.is_ready:set(true, true)
        end
    else
        return client.events.GUILD_CREATE:emit(ctx(new))
    end
end

function GUILD_UPDATE(client, shard, _, event)
    event.id = util.uint(event.id)
    return client.events.GUILD_UPDATE:emit(ctx(guild.upsert(client, event)))
end

function GUILD_DELETE(client, shard, _, event)
    event.id = util.uint(event.id)
    local g = client.cache.guild[event.id]
    if event.unavailable then
        return client.events.GUILD_UNAVAILABLE:emit(ctx(guild.upsert(client, event)))
    else
        return client.events.GUILD_DELETE:emit(ctx(g))
    end
end

function GUILD_BAN_ADD(client, shard, _, event)
    event.guild_id = util.uint(event.guild_id)
    local g = client.cache.guild[event.guild_id]
    local u = user.upsert(client, event.user)
    return client.events.GUILD_BAN_ADD:emit(ctx(g, nil, u))
end

function GUILD_BAN_REMOVE(client, shard, _, event)
    event.guild_id = util.uint(event.guild_id)
    local g = client.cache.guild[event.guild_id]
    local u = user.upsert(client, event.user)
    return client.events.GUILD_BAN_REMOVE:emit(ctx(g, nil, u))
end

local function upsert_map(payload, state, upsert)
    return upsert(state, payload)
end

function GUILD_EMOJIS_UPDATE(client, shard, _, event)
    event.guild_id = util.uint(event.guild_id)
    local g = client.cache.guild[event.guild_id]
    local emojis = list.map(upsert_map, event.emojis, client, emoji.upsert)
    return client.events.GUILD_EMOJIS_UPDATE:emit(ctx{g, emojis = emojis})
end

function GUILD_MEMBER_ADD(client, shard, _, event)
    event.guild_id = util.uint(event.guild_id)
    local g = client.cache.guild[event.guild_id]
    local m = member.upsert(client, event, g.id)
    return client.events.GUILD_MEMBER_ADD:emit(ctx(g, nil, m))
end

function GUILD_MEMBER_UPDATE(client, shard, _, event)
    event.guild_id = util.uint(event.guild_id)
    local g = client.cache.guild[event.guild_id]
    local _ = member.get_from(client, event.guild_id, util.uint(event.user.id))
    local m = member.upsert(client, event, g.id)
    return client.events.GUILD_MEMBER_UPDATE:emit(ctx(g, nil, m))
end

function GUILD_MEMBER_REMOVE(client, shard, _, event)
    event.guild_id = util.uint(event.guild_id)
    event.id = util.uint(event.id)
    local g = client.cache.guild[event.guild_id]
    local m = client.cache.member[event.guild_id] and client.cache.member[event.guild_id][event.id]
    if g and m then
        guild.remove_member(g, m.id)
    end
    if m then
        return client.events.GUILD_MEMBER_REMOVE:emit(ctx(g, nil, m))
    else
        return client.events.GUILD_MEMBER_REMOVE:emit(ctx{g, nil, m; uncached = true})
    end
end

function GUILD_ROLE_CREATE(client, shard, _, event)
    event.role.guild_id = util.uint(event.guild_id)
    local g = client.cache.guild[event.role.guild_id]
    local m = role.upsert(client, event.role)
    return client.events.GUILD_ROLE_CREATE:emit(ctx(g, nil, nil, m))
end

function GUILD_ROLE_UPDATE(client, shard, _, event)
    event.role.guild_id = util.uint(event.guild_id)
    local g = client.cache.guild[event.role.guild_id]
    local _ = role.get_from(client, g.id, util.uint(event.role.id))
    local m = role.upsert(client, event.role)
    return client.events.GUILD_ROLE_UPDATE:emit(ctx(g, nil, nil, m))
end

function GUILD_ROLE_DELETE(client, shard, _, event)
    event.guild_id = util.uint(event.guild_id)
    event.role_id = util.uint(event.role_id)
    local g = client.cache.guild[event.guild_id]
    local r = client.cache.role[event.role_id]
    if r == nil then
        return client.events.GUILD_ROLE_DELETE:emit(ctx{g; role_id = event.role_id, uncached = true})
    else
        return client.events.GUILD_ROLE_DELETE:emit(ctx(g, nil, nil, r))
    end
end

function MESSAGE_CREATE(client, shard, _, event)
    local chid = util.uint(event.channel_id)
    local ch = client.cache.channel[chid]
    if ch == nil then ch = promise.new(channel.get_from, client, chid) end
    local g if event.guild_id then g = client.cache.guild[util.uint(event.guild_id)] end
    local m = message.upsert(client, event, chid)
    return client.events.MESSAGE_CREATE:emit(ctx(g, ch, m.author, nil, m))
end

function MESSAGE_UPDATE(client, shard, _, event)
    local chid = util.uint(event.channel_id)
    local ch = client.cache.channel[chid]
    if ch == nil then ch = promise.new(channel.get_from, client, chid) end
    local g if event.guild_id then g = client.cache.guild[util.uint(event.guild_id)] end

    message.get_from(client, chid, util.uint(event.id))
    local m = message.upsert(client, event, chid)
    return client.events.MESSAGE_UPDATE:emit(ctx(g, ch, m.author, nil, m))
end

function MESSAGE_DELETE(client, shard, _, event)
    local chid = util.uint(event.channel_id)
    local ch = client.cache.channel[chid]
    if ch == nil then ch = promise.new(channel.get_from, client, chid) end
    local g if event.guild_id then g = client.cache.guild[util.uint(event.guild_id)] end
    local m = client.cache.message[ch.id] and client.cache.message[ch.id][util.uint(event.id)]
    if m == nil then
        return client.events.MESSAGE_DELETE:emit(ctx{g, ch, nil, nil, event; uncached = true, id = true})
    else
        return client.events.MESSAGE_DELETE:emit(ctx(g, ch, m.author, nil, m))
    end
end

function MESSAGE_DELETE_BULK(client, shard, _, event)
    local ch = channel.get(util.uint(event.channel_id))
    local g if event.guild_id then g = client.cache.guild[util.uint(event.guild_id)] end
    for _, id in ipairs(event.ids) do
        local m = client.cache.message[ch.id][util.uint(id)]
        if m == nil then
            client.events.MESSAGE_DELETE:emit(ctx{g, ch, nil, nil, event; uncached = true})
        else
            client.events.MESSAGE_DELETE:emit(ctx(g, ch, m.author, nil, m))
        end
    end
end

function MESSAGE_REACTION_ADD(client, shard, _, event)
    local chid = util.uint(event.channel_id)
    local ch = client.cache.channel[chid]
    local uid = util.uint(event.user_id)
    local u = client.cache.user[uid]
    local g if event.guild_id then g = client.cache.guild[util.uint(event.guild_id)] end

    local mid = util.uint(event.message_id)
    local m = client.cache.message[chid] and client.cache.message[chid][mid]
    if m then
        local rid = reaction.processor.emoji(event, client)
        local r = m.reactions[rid] or reaction.upsert(client, {
             emoji = event.emoji
            ,count = 0
            ,me = uid == client.app.id
        })
        r.count = r.count+1
        return client.events.MESSAGE_REACTION_ADD:emit(ctx{g, ch, u, nil, m; reaction = r})
    else
        return client.events.MESSAGE_REACTION_ADD:emit(
        ctx{g, ch, u, nil, nil;
             reaction = event
            ,uncached = true
        })
    end
end

function MESSAGE_REACTION_REMOVE(client, shard, _, event)
    local chid = util.uint(event.channel_id)
    local ch = client.cache.channel[chid]
    local uid = util.uint(event.user_id)
    local u = client.cache.user[uid]
    local g if event.guild_id then g = client.cache.guild[util.uint(event.guild_id)] end

    local mid = util.uint(event.message_id)
    local m = client.cache.message[chid] and client.cache.message[chid][mid]
    if m then
        local rid = reaction.processor.emoji(event, client)
        local r = m.reactions[rid] or reaction.upsert(client, {
             emoji = event.emoji
            ,count = 1
            ,me = uid == client.app.id
        })
        r.count = r.count-1
        return client.events.MESSAGE_REACTION_REMOVE:emit(ctx{g, ch, u, nil, m; reaction = r})
    else
        return client.events.MESSAGE_REACTION_REMOVE:emit(
        ctx{g, ch, u, nil, nil;
             reaction = event
            ,uncached = true
        })
    end
end

local function zero_count(r)
    r.count = 0
end

function MESSAGE_REACTION_REMOVE_ALL(client, shard, _, event)
    local chid = util.uint(event.channel_id)
    local ch = client.cache.channel[chid]
    local uid = util.uint(event.user_id)
    local u = client.cache.user[uid]
    local g if event.guild_id then g = client.cache.guild[util.uint(event.guild_id)] end

    local mid = util.uint(event.message_id)
    local m = client.cache.message[chid] and client.cache.message[chid][mid]
    if m == nil then
        client.events.MESSAGE_REACTION_REMOVE_ALL:emit(ctx{g, ch, u, nil, nil; uncached = true})
    else
        list.each(zero_count, m.reactions)
        m.reactions = {}
        client.events.MESSAGE_REACTION_REMOVE_ALL:emit(ctx(g, ch, u, nil, m))
    end
end

function CHANNEL_PINS_UPDATE(client, shard, _, event)
    local chid = util.uint(event.channel_id)
    local ch = client.cache.channel[chid]
    if ch then
        return client.events.CHANNEL_PINS_UPDATE:emit(ctx(ch.guild, ch, nil, nil, nil))
    else
        return client.events.CHANNEL_PINS_UPDATE:emit(ctx{nil, event, uncached = true})
    end
end

--end-module--
return _ENV
