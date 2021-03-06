--imports--
local api = require"novus.api"
local shard = require"novus.shard"
local util = require"novus.snowflakes.helpers"
local list = require"novus.util.list"
local view = require"novus.cache.view"
local snowflake = require"novus.snowflakes"
local const = require"novus.const"
local enums = require"novus.enums"
local json = require"cjson"
local cqueues = require"cqueues"
local cache = require"novus.cache"
local pretty = require"pl.pretty"
local setmetatable = setmetatable
local ipairs, pairs = ipairs, pairs
local tonumber = tonumber
local insert = table.insert
local sort = table.sort
local ult = math.ult
local assert = assert
local type = type
local MAX, MIN = math.maxinteger, math.mininteger
local max,min = math.max, math.min
local gettime = cqueues.monotime
local running = cqueues.running
local snowflakes = snowflake.snowflakes
local null = json.null
local channeltype = enums.channeltype
local should_debug = os.getenv"NOVUS_DEBUG"

local role           = require"novus.snowflakes.guild.role"
local emoji          = require"novus.snowflakes.guild.emoji"
local invite         = require"novus.snowflakes.guild.invite"
local webhook        = require"novus.snowflakes.guild.webhook"
local ban            = require"novus.snowflakes.guild.ban"
local member         = require"novus.snowflakes.guild.member"
local auditlog_entry = require"novus.snowflakes.guild.auditlog-entry"

local textchannel    = require"novus.snowflakes.guild.textchannel"
local voicechannel   = require"novus.snowflakes.guild.voicechannel"
local category       = require"novus.snowflakes.guild.categorychannel"

--start-module--
local _ENV = snowflake "guild"

--[[
id	snowflake	guild id
name	string	guild name (2-100 characters)
icon	?string	icon hash
splash	?string	splash hash
owner?	boolean	whether or not the user is the owner of the guild
owner_id	snowflake	id of owner
permissions?	integer	total permissions for the user in the guild (does not include channel overrides)
region	string	voice region id for the guild
afk_channel_id	?snowflake	id of afk channel
afk_timeout	integer	afk timeout in seconds
embed_enabled?	boolean	is this guild embeddable (e.g. widget)
embed_channel_id?	snowflake	if not null, the channel id that the widget will generate an invite to
verification_level	integer	verification level required for the guild
default_message_notifications	integer	default message notifications level
explicit_content_filter	integer	explicit content filter level
roles	array of role objects	roles in the guild
emojis	array of emoji objects	custom guild emojis
features	array of strings	enabled guild features
mfa_level	integer	required MFA level for the guild
application_id	?snowflake	application id of the guild creator if it is bot-created
widget_enabled?	boolean	whether or not the server widget is enabled
widget_channel_id?	snowflake	the channel id for the server widget
system_channel_id	?snowflake	the id of the channel to which system messages are sent
joined_at? *	ISO8601 timestamp	when this guild was joined at
large? *	boolean	whether this is considered a large guild
unavailable? *	boolean	is this guild unavailable
member_count? *	integer	total number of members in this guild
voice_states? *	array of partial voice state objects	(without the guild_id key)
members? *	array of guild member objects	users in the guild
channels? *	array of channel objects	channels in the guild
presences? *	array of partial presence update objects	presences of the users in the guild
]]

schema{
    "unavailable"
    ,"name"
    ,"icon"
    ,"splash"
    ,"is_owner"
    ,"owner_id"
    ,"permissions"
    ,"region"
    ,"afk_channel_id"
    ,"afk_timeout"
    ,"embed_enabled"
    ,"embed_channel_id"
    ,"verification_level"
    ,"default_message_notifications"
    ,"explicit_content_filter"
    ,"role_ids"
    ,"emoji_ids"
    ,"features"
    ,"mfa_level"
    ,"application_id"
    ,"widget_enabled"
    ,"widget_channel_id"
    ,"system_channel_id"
    ,"joined_at"
    ,"large"
    ,"member_count"
    ,"lazy"
    ,"vanity_url_code"
    ,"banner"
    ,"description"
    ,"voice_states"
    ,"member_ids"
    ,"channel_ids"
    ,"presences"
    ,"members"
    ,"channels"
    ,"emojis"
    ,"roles"
}

function processor.roles(roles, state, object)
    local out = {}
    for i, r in ipairs(roles) do
        local rid = util.uint(r.id)
        if not state.cache.role[rid] then
            r.guild_id = object.id
            snowflakes.role.new_from(state, r)
        end
        out[i] = rid
    end
    return out, "role_ids"
end

function processor.emojis(emojis, state, object)
    local out = {}
    for i, e in ipairs(emojis) do
        local eid = util.uint(e.id)
        if not state.cache.emoji[eid] then
            e.guild_id = object.id
            snowflakes.emoji.new_from(state, e)
        end
        out[i] = eid
    end
    return out, "emoji_ids"
end

function processor.members(mems, state, object)
    local out = {}
    for i, m in ipairs(mems) do
        local mid = util.uint(m.id)
        m.guild_id = object.id
        if not state.cache.member[mid] then
            snowflakes.member.new_from(state, m)
        end
        out[i] = mid
    end
    return out, "member_ids"
end

function processor.channels(chls, state, object)
    local out = {}
    for i, c in ipairs(chls) do
        local cid = util.uint(c.id)
        c.guild_id = object.id
        if not state.cache.channel[cid] then
            snowflakes.channel.new_from(state,c)
        end
        out[i] = cid
    end
    return out, "channel_ids"
end

local function insert_gid(v, _, id)
    v.guild_id = id
    v.user_id = util.uint(v.user_id)
    v.channel_id = util.uint(v.channel_id)
end

function processor.voice_states(states, _, guild)
    list.each(insert_gid, states, guild[1])
    return states
end

function processor.owner(o)
    return o, "is_owner"
end

local function select_guild_snowflake(_, mem, gid)
    if mem.guild_id == gid then
        return mem
    end
end


local function new_from_available(state, payload)
    local gid = util.uint(payload.id)
    local old = state.cache.guild[gid] or {id = gid}
    local object = setmetatable(util.mergewith(old, {
         gid
        ,old[2] or gettime()
        ,state.cache.methods.guild
        ,false
        ,payload.name
        ,payload.icon
        ,payload.splash
        ,payload.owner
        ,payload.owner_id
        ,payload.permissions
        ,payload.region
        ,payload.afk_channel_id
        ,payload.afk_timeout
        ,payload.embed_enabled
        ,payload.embed_channel_id
        ,payload.verification_level
        ,payload.default_message_notifications
        ,payload.explicit_content_filter
        ,processor.roles(payload.roles, state, old)
        ,processor.emojis(payload.emojis, state, old)
        ,payload.features
        ,payload.mfa_level
        ,payload.application_id
        ,payload.widget_enabled
        ,payload.widget_channel_id
        ,payload.system_channel_id
        ,payload.joined_at
        ,payload.large
        ,payload.member_count
        ,not not payload.lazy
        ,payload.vanity_url_code
        ,payload.banner
        ,payload.description
    }),_ENV)

    if payload.voice_states then
        object.voice_states = processor.voice_states(payload.voice_states, state, object)
    end
    if payload.members then
        object.member_ids = processor.members(payload.members, state, object)
    end
    if payload.channels then
        object.channel_ids = processor.channels(payload.channels, state, object)
    end
    -- if payload.presences then
    --     object.presences = payload.presences
    -- end

    local mycache = state.cache.member[gid]
    if mycache == nil then
        state.cache.member[gid] = util.cache()
        state.cache.methods.member[gid] = cache.inserter(state.cache.member[gid])
    end

    object.members  = object.members or view.new(state.cache.member[gid], select_guild_snowflake, gid)
    object.channels = object.channels or view.new(state.cache.channel, select_guild_snowflake, gid)
    object.roles    = object.roles or view.new(state.cache.role, select_guild_snowflake, gid)
    object.emojis   = object.emojis  or view.new(state.cache.emoji, select_guild_snowflake, gid)

    if should_debug then
      for k, v in pairs(payload) do
        if not schema[k] then
          util.warn("%s has extra key %s (a %s) %s", object.id, k, type(v), v)
        end
      end
    end
    return object
end

function new_from(state, payload)
    if payload.unavailable then
        return setmetatable({
             util.uint(payload.id)
            ,gettime()
            ,state.cache.methods.guild
            ,true
        }, _ENV)
    else
        return new_from_available(state, payload)
    end
end

function remove_member(guild, id)
    guild.members = view.remove_key(guild.members, id)
end

function remove_channel(guild, id)
    guild.members = view.remove_key(guild.channels, id)
end

function remove_role(guild, id)
    guild.roles = view.remove_key(guild.roles, id)
end

function remove_emoji(guild, id)
    guild.emojis = view.remove_key(guild.emojis, id)
end

function modify(snowflake, by)
    local state = running():novus()
    local success, data, err = api.modify_guild(state.api, snowflake[1], by)
    if success and data then
        return new_from_available(state, data)
    else
        return nil, err
    end
end

function properties.shard_id(guild)
    local state = running():novus()
    return (guild[1] >> 22) % state.total_shards
end

function methods.request_members(guild)
    local state = running():novus()
    local shard_id = (guild[1] >> 22) % state.total_shards

    local this_shard = state.shards[shard_id]
    if not this_shard then
        return false, 'Shard-%s does not exist?' % shard_id
    end
    this_shard.is_ready:get()
    return shard.request_guild_members(this_shard, guild[1])
end

function methods.get_member(guild, id)
    id = snowflake.id(id)
    if id then
        local this_member = guild.members[id]
        if this_member then
            return this_member
        else
            return member.get(guild[1], id)
        end
    end
end

function methods.get_role(guild, id)
    id = snowflake.id(id)
    if id then
        local this_role = guild.roles[id]
        if this_role then
            return this_role
        else
            return role.get(guild[1], id)
        end
    end
end

function methods.get_emoji(guild, id)
    id = snowflake.id(id)
    if id then
        local this_emoji = guild.emojis[id]
        if this_emoji then
            return this_emoji
        else
            return emoji.get(guild[1], id)
        end
    end
end

function methods.get_channel(guild, id)
    id = snowflake.id(id)
    if id then
        local this_channel = guild.channels[id]
        if this_channel then
            return this_channel
        else
            local ch, err = snowflakes.channel.get(id)
            if ch and ch.guild_id == guild[1] then
                return ch
            else
                return nil, err or 'Channel not found or contained in %s.' % guild
            end
        end
    end
end

function methods.create_text_channel(guild, name)
    local state = running():novus()
    local success, data, err = api.create_guild_channel(state.api, guild[1], {
         name = name
        ,type = channeltype.text
    })
    if success then
        return textchannel.new_from(state, data)
    else
        return nil, err
    end
end

function methods.create_voice_channel(guild, name)
    local state = running():novus()
    local success, data, err = api.create_guild_channel(state.api, guild[1], {
         name = name
        ,type = channeltype.voice
    })
    if success then
        return voicechannel.new_from(state, data)
    else
        return nil, err
    end
end

function methods.create_category(guild, name)
    local state = running():novus()
    local success, data, err = api.create_guild_channel(state.api, guild[1], {
         name = name
        ,type = channeltype.category
    })
    if success then
        return category.new_from(state, data)
    else
        return nil, err
    end
end

function methods.create_role(guild, name)
    local state = running():novus()
    local success, data, err = api.create_guild_role(state.api, guild[1], {
         name = name
    })
    if success then
        data.guild_id = guild[1]
        return role.new_from(state, data)
    else
        return nil, err
    end
end

function methods.create_emoji(guild, name, image)
    local state = running():novus()
    local success, data, err = api.create_guild_emoji(state.api, guild[1], {
          name = name
         ,image = image
    })
    if success then
        data.guild_id = guild[1]
        return emoji.new_from(state, data)
    else
        return nil, err
    end
end

function methods.set_name(guild, name)
    return modify(guild, {name = name or null})
end

function methods.set_region(guild, region)
    return modify(guild, {region = region})
end

function methods.set_verification_level(guild, level)
    if enums.verificationlevel[level] == nil then
        util.throw("Invalid verification level %s", level)
    end
    if type(enums.verificationlevel[level]) == 'number' then
        level = enums.verificationlevel[level]
    end
    return modify(guild, {verification_level = level or null})
end

function methods.set_notification_level(guild, level)
    if enums.notificationlevel[level] == nil then
        util.throw("Invalid notification level %s", level)
    end
    if type(enums.notificationlevel[level]) == 'number' then
        level = enums.notificationlevel[level]
    end
    return modify(guild, {default_message_notifications = level or null})
end

function methods.set_explicit_content_level(guild, level)
    if enums.explicitcontentlevel[level] == nil then
        util.throw("Invalid explicit content level %s", level)
    end
    if type(enums.explicitcontentlevel[level]) == 'number' then
        level = enums.explicitcontentlevel[level]
    end
    return modify(guild, {explicit_content_filter = level or null})
end

function methods.set_afk_timout(guild, timeout)
    return modify({afk_timeout = timeout or null})
end

function methods.set_afk_channel(guild, id)
    id = snowflake.id(id)
    return modify(guild, {afk_channel = id or null})
end

function methods.set_system_channel(guild, id)
    id = snowflake.id(id)
    return modify(guild, {system_channel = id or null})
end

function methods.set_owner(guild, id)
    id = snowflake.id(id)
    return modify(guild, {owner_id = id or null})
end

function methods.set_icon(guild, icon)
    return modify(guild, {icon = icon or null})
end

function methods.set_splash(guild, icon)
    return modify(guild, {splash = icon or null})
end

function methods.get_prune_count(guild, days)
    local state = running():novus()
    local success, data, err = api.get_guild_prune_count(state.api, guild[1], days and {days = days} or nil)
    if success then
        return data.pruned
    else
        return nil, err
    end
end

function methods.prune_members(guild, days, count)
    local state = running():novus()
    if type(days) == 'boolean' then
        count = days
        days = nil
    end

    local success, data, err = api.begin_guild_prune(state.api, guild[1], {
         days = days
        ,compute_prune_count = not not count
    })

    if success then
        return data.pruned
    else
        return nil, err
    end
end

function methods.get_bans(guild)
    local state = running():novus()
    local success, data, err = api.get_guild_bans(state.api, guild[1])

    if success then
        return list.map(snowflakes.ban.new_from, data, state)
    else
        return nil, err
    end
end

function methods.get_ban(guild, id)
    id = snowflake.id(id)
    return snowflakes.ban.get(guild[1], id)
end

function methods.get_invites(guild)
    local state = running():novus()
    local success, data, err = api.get_guild_invites(state.api, guild[1])

    if success then
        return list.map(snowflakes.invite.new_from, data, state)
    else
        return nil, err
    end
end

function methods.get_webhooks(guild)
    local state = running():novus()
    local success, data, err = api.get_guild_webhooks(state.api, guild[1])

    if success then
        return list.map(snowflakes.webhook.new_from, data, state)
    else
        return nil, err
    end
end

function methods.get_voice_regions(guild)
    local state = running():novus()
    local success, data, err = api.get_guild_voice_regions(state.api, guild[1])
    if success then
        return data
    else
        return nil, err
    end
end

function methods.leave(guild)
    local state = running():novus()
    local success, data, err = api.leave_guild(state.api, guild[1])
    if success then
        return true
    else
        return nil, err
    end
end

function methods.delete(guild)
    local state = running():novus()
    local success, data, err = api.delete_guild(state.api, guild[1])
    if success then
        snowflake.destroy(guild)
        return true
    else
        return nil, err
    end
end

function methods.kick(guild, mem, reason)
    local id = snowflake.id(mem)
    if id then
        local query = reason and {reason = reason} or nil
        local state = running():novus()
        local success, data, err = api.remove_guild_member(state.api, guild[1], id, query)
        if success then
            return true
        else
            return nil, err
        end
    end
end

function methods.ban(guild, id, reason, days)
    id = snowflake.id(id)
    if id then
        local state = running():novus()
        local payload = {}
        if reason then
            payload.reason = reason
        end
        if days then
            payload["delete-message-days"] = days
        end
        local success, data, err = api.create_guild_ban(state.api, guild[1], id, payload)
        if success then
            return true
        else
            return nil, err
        end
    end
end

function methods.unban(guild, id, reason)
    id = snowflake.id(id)
    if id then
        local query = reason and {reason = reason}
        local state = running():novus()
        local success, data, err = api.remove_guild_ban(state.api, guild[1], id, query)
        if success then
            return true
        else
            return nil, err
        end
    end
end

local function new_role(data, _, state, gid)
    data.guild_id = gid
    return role.upsert(state, data)
end

function methods.loadget_role(guild, id)
    id = snowflake.id(id)
    local state = running():novus()
    local success, data, err = api.get_guild_roles(state.api, guild.id)
    if success then
        list.each(new_role, data, state, guild.id)
        if id then return state.cache.role[id] else return true end
    else
        return nil, err
    end
end

function methods.populate_channels(guild)
    list.each(snowflakes.channel.get, guild.channel_ids)
    return guild.channels
end

local function sorter(a, b)
	if a.position == b.position then
		return ult(a.id, b.id)
	else
		return a.position < b.position
	end
end

local channel_prop_types = {
     text  = 'text_channels'
    ,voice = 'voice_channels'
    ,category = 'categories'
}

local function sorted_channels(guild, type)
    guild:populate_channels()
    type = channel_prop_types[type] or channel_prop_types[channeltype[type]]
    local out = {}
    for id, channel in pairs(guild[type]) do
        insert(out, {id = id, position = channel.position})
    end
    sort(out, sorter)
    return out
end

local function sorted_roles(guild)
    guild:loadget_role()
    local out = {}
    for id, role in pairs(guild.roles) do
        if id ~= guild.id then
            insert(out, {id = id, position = role.position})
        end
    end
    sort(out, sorter)
    return out
end

local function fix_ids (v) v.id = util.uint.tostring(v.id) end

local function set_sorted_channels(guild, channels)
    list.each(fix_ids, channels)
    local success, _, err = api.modify_guild_channel_positions(running():novus().api, guild.id, channels)
    return success, err
end

local function set_sorted_roles(guild, roles)
    insert(roles, {id = guild.id, position = 0})
    list.each(fix_ids, roles)
    local success, _, err = api.modify_guild_role_positions(running():novus().api, guild.id, roles)
    return success, err
end

function methods.move_role_up(guild, role, n)
    assert(type(n) == "number", "Must provide a number value.")
    n = ~~n
    if n < 0 then
        return guild:move_role_down(role, -n)
    end

    local roles = sorted_roles(guild)

    local new = MAX
	for i = #roles - 1, 0, -1 do
		local v = roles[i + 1]
		if v.id == role.id then
			new = max(0, i - n)
			v.position = new
		elseif i >= new then
			v.position = i + 1
		else
			v.position = i
		end
    end
    return set_sorted_roles(guild, roles)
end

function methods.move_role_down(guild, role, n)
    assert(type(n) == "number", "Must provide a number value.")
    n = ~~n
    if n < 0 then
        return guild:move_role_up(role, -n)
    end

    local roles = sorted_roles(guild)

    local new = MIN
	for i = 0, #roles - 1 do
		local v = roles[i + 1]
		if v.id == roles.id then
			new = min(i + n, #roles - 1)
			v.position = new
		elseif i <= new then
			v.position = i - 1
		else
			v.position = i
		end
	end
    return set_sorted_roles(guild, roles)
end

function methods.move_channel_up(guild, channel, n)
    assert(type(n) == "number", "Must provide a number value.")
    n = ~~n
    if n < 0 then
        return guild:move_channel_down(channel, -n)
    end

    local channels = sorted_channels(guild, channel.type)
    pretty.dump(channels)
    local new = MAX
	for i = #channels - 1, 0, -1 do
		local v = channels[i + 1]
		if v.id == channel.id then
			new = max(0, i - n)
			v.position = new
		elseif i >= new then
			v.position = i + 1
		else
			v.position = i
		end
    end
    pretty.dump(channels)
    return set_sorted_channels(guild, channels)
end

function methods.move_channel_down(guild, channel, n)
    assert(type(n) == "number", "Must provide a number value.")
    n = ~~n
    if n < 0 then
        return guild:move_channel_up(channel, -n)
    end

    local channels = sorted_channels(guild, channel.type)

    local new = MIN
	for i = 0, #channels - 1 do
		local v = channels[i + 1]
		if v.id == channel.id then
			new = min(i + n, #channels - 1)
			v.position = new
		elseif i <= new then
			v.position = i - 1
		else
			v.position = i
		end
	end
    return set_sorted_channels(guild, channels)
end

function properties.icon_url(guild)
    return const.api.icon_endpoint % {guild[1], guild.icon}
end

local function select_channel_type(_, chan, typ)
    if chan.type == typ then
        return chan
    end
end

function properties.text_channels(guild)
    return view.new(guild.channels, select_channel_type, channeltype.text)
end

function properties.voice_channels(guild)
    return view.new(guild.channels, select_channel_type, channeltype.voice)
end

function properties.categories(guild)
    return view.new(guild.channels, select_channel_type, channeltype.category)
end

function properties.splash_url(guild)
    return const.api.splash_endpoint % {guild[1], guild.splash}
end

function properties.me(guild)
    local state = running():novus()
    return guild:get_member(state:me().id)
end

function properties.owner(guild)
    return guild:get_member(guild.owner_id)
end

function properties.default_role(guild)
    return guild:get_role(guild[1])
end

function properties.system_channel(guild)
    return guild:get_channel(guild.system_channel_id)
end

function get_from(state, id)
    local cache = state.cache.guild
    if cache[id] then return cache[id]
    else
        local success, data, err = api.get_guild(state.api, id)
        if success then
            return new_from(state, data)
        else
            return nil, err
        end
    end
end

--__gc = nil

--end-module--
return _ENV