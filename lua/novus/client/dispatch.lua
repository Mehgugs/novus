--imports--
local cond = require"cqueues.condition"
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
    local message = require"novus.snowflakes.channel.message"


local ipairs = ipairs
local insert = table.insert
local function select_dms(_, chan)
    return chan.type == enums.channeltype.private and chan or nil
end



--start-module--
local _ENV = {}

function READY(client, shard, _, event)
    if event.v ~= const.gateway.version then
        return util.fatal("Gateway responded with an incorrect version: %s", event.v)
    end
    shard.session_id = event.session_id
    user.new_from(client, event.user)

    for _, chan in ipairs(event.private_channels) do
        if chan.type == enums.channeltype.private then
            dm.new_from(client, chan)
        end
    end

    client.dms = view.new(client.cache.channel, select_dms)

    shard.to_load = #event.guilds
    shard.loading = 0
    for _, g in ipairs(event.guilds) do
        guild.new_from(client, g)
    end
    return client.events.SHARD_READY:enqueue(ctx{shard = shard.options.id})
end

function RESUMED(client, shard, _, event)
    util.info("Shard-%s has resumed trace=%q", shard.options.id, concat(event._trace, ', '))
    return client.events.RESUMED:enqueue(ctx{shard = shard.options.id})
end

local function load_members(m, _, state, gid)
    m.guild_id = gid
    member.new_from(state, m)
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
    return client.events.CHANNEL_CREATE:enqueue(ctx(g, channel.new_from(event)))
end

function CHANNEL_UPDATE(client, shard, _, event)
    local has_guild = enums.channeltype[event.type]:startswith"guild"
    local g
    event.guild_id = util.uint(event.guild_id)
    if has_guild then
        g = guild.get_from(client, event.guild_id)
    end
    return client.events.CHANNEL_UPDATE:enqueue(ctx(g, channel.new_from(event)))
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
        return client.events.CHANNEL_DELETE:enqueue(ctx(g, channel))
    else
        return client.events.CHANNEL_DELETE:enqueue(ctx{uncached = true, g, event})
    end
end

function GUILD_CREATE(client, shard, _, event)
    event.id = util.uint(event.id)
    local g = client.cache.guild[event.id]
    local was_unavailable = g and g.unavailable
    local new = guild.new_from(client, event)
    if g then
        shard.loading = shard.loading + 1
        shard.to_load = shard.to_load - 1
        if was_unavailable and not event.unavailable then
            client.events.GUILD_AVAILABLE:enqueue(ctx(new))
        end
        if shard.to_load == 0 then
            shard.is_ready:set(true, true)
        end
    else
        return client.events.GUILD_CREATE:enqueue(ctx(new))
    end
end

function GUILD_UPDATE(client, shard, _, event)
    event.id = util.uint(event.id)
    local g = client.cache.guild[event.id]
    return client.events.GUILD_UPDATE:enqueue(ctx(guild.new_from(client, event, g)))
end

function GUILD_DELETE(client, shard, _, event)
    event.id = util.uint(event.id)
    local g = client.cache.guild[event.id]
    if event.unavailable then
        return client.events.GUILD_UNAVAILABLE:enqueue(ctx(guild.new_from(client, event, g)))
    else
        return client.events.GUILD_DELETE:enqueue(ctx(g))
    end
end

function GUILD_BAN_ADD(client, shard, _, event)
    event.guild_id = util.uint(event.guild_id)
    local g = client.cache.guild[event.guild_id]
    local u = user.new_from(client, event.user)
    return client.events.BAN_ADD:enqueue(ctx(g, nil, u))
end

function GUILD_BAN_REMOVE(client, shard, _, event)
    event.guild_id = util.uint(event.guild_id)
    local g = client.cache.guild[event.guild_id]
    local u = user.new_from(client, event.user)
    return client.events.BAN_REMOVE:enqueue(ctx(g, nil, u))
end

local function new_from_map(payload, state, new_from, old)
    return new_from(state, payload, old)
end

function GUILD_EMOJIS_UPDATE(client, shard, _, event)
    event.guild_id = util.uint(event.guild_id)
    local g = client.cache.guild[event.guild_id]
    local emojis = list.map(new_from_map, event.emojis, client, emoji.new_from)
    return client.events.EMOJIS_UPDATE:enqueue(ctx{g, emojis = emojis})
end

function GUILD_MEMBER_ADD(client, shard, _, event)
    event.guild_id = util.uint(event.guild_id)
    local g = client.cache.guild[event.guild_id]
    local m = member.new_from(state, event)
    return client.events.MEMBER_ADD:enqueue(ctx(g, nil, m))
end

function GUILD_MEMBER_UPDATE(client, shard, _, event)
    event.guild_id = util.uint(event.guild_id)
    local g = client.cache.guild[event.guild_id]
    local m = member.new_from(state, event)
    return client.events.MEMBER_UPDATE:enqueue(ctx(g, nil, m))
end

function GUILD_MEMBER_REMOVE(client, shard, _, event)
    event.guild_id = util.uint(event.guild_id)
    event.id = util.uint(event.id)
    local g = client.cache.guild[event.guild_id]
    local m = client.cache.member[event.guild_id][event.id]
    if g and m then
        guild.remove_member(g, m.id)
    end
    if m then
        return client.events.MEMBER_REMOVE:enqueue(ctx(g, nil, m))
    else
        return client.events.MEMBER_REMOVE:enqueue(ctx{g, nil, m; uncached = true})
    end
end

function GUILD_ROLE_CREATE(client, shard, _, event)
    event.guild_id = util.uint(event.guild_id)
    local g = client.cache.guild[event.guild_id]
    local m = role.new_from(client, event)
    return client.events.ROLE_CREATE:enqueue(ctx(g, nil, nil, m))
end

function GUILD_ROLE_UPDATE(client, shard, _, event)
    event.guild_id = util.uint(event.guild_id)
    local g = client.cache.guild[event.guild_id]
    local m = role.new_from(client, event)
    return client.events.ROLE_UPDATE:enqueue(ctx(g, nil, nil, m))
end

function GUILD_ROLE_DELETE(client, shard, _, event)
    event.guild_id = util.uint(event.guild_id)
    event.role_id = util.uint(event.role_id)
    local g = client.cache.guild[event.guild_id]
    local r = client.cache.role[event.role_id]
    if r == nil then
        return client.events.ROLE_DELETE:enqueue(ctx{g; role_id = event.role_id, uncached = true})
    else
        return client.events.ROLE_DELETE:enqueue(ctx(g, nil, nil, r))
    end
end

function MESSAGE_CREATE(client, shard, _, event)
    local ch = channel.get(util.uint(event.channel_id))
    local g if event.guild_id then g = client.cache.guild[util.uint(event.guild_id)] end
    local m = message.new_from(client, event)
    return client.events.MESSAGE_CREATE:enqueue(ctx(g, ch, m.author, nil, m))
end

function MESSAGE_UPDATE(client, shard, _, event)
    local ch = channel.get(util.uint(event.channel_id))
    local g if event.guild_id then g = client.cache.guild[util.uint(event.guild_id)] end
    local m = message.new_from(client, event)
    return client.events.MESSAGE_UPDATE:enqueue(ctx(g, ch, m.author, nil, m))
end

function MESSAGE_DELETE(client, shard, _, event)
    local ch = channel.get(util.uint(event.channel_id))
    local g if event.guild_id then g = client.cache.guild[util.uint(event.guild_id)] end
    local m = client.cache.message[ch.id][util.uint(event.id)]
    if m == nil then
        return client.events.MESSAGE_DELETE:enqueue(ctx{g, ch, m.author, nil, event; uncached = true})
    else
        return client.events.MESSAGE_DELETE:enqueue(ctx(g, ch, m.author, nil, m))
    end
end





--end-module--
return _ENV
