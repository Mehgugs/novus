--imports--
local api = require"novus.api"
local cache = require"novus.cache"
local util = require"novus.snowflakes.helpers"
local list = require"novus.util.list"
local snowflake = require"novus.snowflakes"
local modifiable = require"novus.snowflakes.mixins.modifiable"
local cqueues = require"cqueues"
local perms = require"novus.util.permission"
local setmetatable = setmetatable
local gettime = cqueues.monotime
local running = cqueues.running
local snowflakes = snowflake.snowflakes
local insert, sort = table.insert, table.sort
local huge = math.huge
local should_debug = _G.NOVUS_DEBUG or os.getenv"NOVUS_DEBUG"
local debugger = debug.debug
--start-module--
local _ENV = snowflake "member"

schema {
     "guild_id"
    ,"nick"
    ,"roles"
    ,"joined_at"
    ,"deaf"
    ,"mute"
    ,"channel_id"
}

function new_from(state, payload, old)
    local user = payload.user
    local id = util.uint(user.id)
    if not state.cache.user[id] then
        snowflakes.user.new_from(state, user)
    end

    local guild_id = util.uint(payload.guild_id) or (old and old.id)
    if guild_id == nil then
        util.error("Cannot construct a member without a guild_id!")
        if should_debug then
            debugger()
        end
        util.fatal("Cannot construct a member without a guild_id!")
    end

    local mycache = state.cache.member[guild_id]
    local method = state.cache.methods.member[guild_id]
    if mycache == nil then
        mycache = util.cache()
        state.cache.message[guild_id] = mycache
        method = cache.inserter(mycache)
    end


    return setmetatable({
         id
        ,gettime()
        ,method
        ,guild_id
        ,payload.nick
        ,payload.roles
        ,payload.joined_at
        ,payload.deaf
        ,payload.mute
        ,util.uint(payload.channel_id)
    }, _ENV)
end

_ENV = modifiable(_ENV, api.modify_guild_member) -- endow with modify

function methods.add_role(member, id)
    id = snowflake.id(id)
    if id then
        if util.includes(member[6], id) then return member end
        local state = running():novus()
        local success, _, err = api.add_guild_member_role(state.api, member[4], member[1], id)
        if success then
            insert(member[6], id)
            return member
        else
            return nil, err
        end
    end
end

local function not_eq(A,B) return A ~= B end

function methods.remove_role(member, id)
    id = snowflake.id(id)
    if id then
        if not util.includes(member[6], id) then return member end
        local state = running():novus()
        local success, _, err = api.remove_guild_member_role(state.api, member[4], member[1], id)
        if success then
            member[6] = list.filter(member[6], not_eq, id)
            return member
        else
            return nil, err
        end
    end
end

function methods.has_role(member, id) return util.includes(member[6], id) end

function methods.set_nickname(member, nick)
    nick = nick or ''
    local state = running():novus()
    local success, data, err
    if member[1] == state.app.id then
        success, data, err = api.modify_current_user_nick(state.api, member[4], member[1], {nick = nick})
    else
        success, data, err = api.modify_guild_member(state.api, member[4], member[1], {nick = nick})
    end
    if success then
        return new_from(state, data, member)
    else
        return nil, err
    end
end

function methods.set_voice_channel(member, id)
    return modify(member, {channel_id = id})
end

function methods.mute(member)
    return modify(member, {mute = true})
end

function methods.deafen(member)
    return modify(member, {deaf = true})
end

function methods.unmute(member)
    return modify(member, {mute = false})
end

function methods.undeafen(member)
    return modify(member, {deaf = false})
end

local permissioned = {
     guildtextchannel = true
    ,guildvoicechannel = true
    ,guildcategorychannel = true
}

function methods.get_permissions(member, channel)
    local guild = member.guild
    if channel and not (snowflake.id(channel) and permissioned[channel.kind]) then
        util.throw("Object is not a valid guildchannel %s", channel)
    end

    if member[1] == guild.owner_id then
        return perms.new(perms.ALL)
    end

    local ret = perms.new(guild.default_role.permissions)
    local overwrites = channel[11]
    local used_overwrites = {perms.new(),perms.new()}
    for id, role in pairs(member.role_objects) do
        ret:union(role[9])
        if overwrites[id] and id ~= guild[1] then
            used_overwrites[1]:union(overwrites[id].allow)
            used_overwrites[2]:union(overwrites[id].deny)
        end
    end

    if ret:contains'administrator' then
        return perms.new(perms.ALL)
    end

    if channel then

        local everyone = overwrites[guild[1]]
        if everyone then
            ret:complement(everyone.deny)
            ret:union(everyone.allow)
        end
        ret:complement(used_overwrites[2])
        ret:union(used_overwrites[1])

        local myoverwrite = overwrites[member[1]]
        if myoverwrite then
            ret:complement(myoverwrite.allow)
            ret:union(myoverwrite.deny)
        end
    end
    return ret
end

function methods.kick(member, reason)
    local parent = snowflakes.guild.get(member[4])
    return parent:kick(member, reason)
end

function methods.ban(member, reason)
    local parent = snowflakes.guild.get(member[4])
    return parent:ban(member, reason)
end

function methods.unban(member)
    local parent = snowflakes.guild.get(member[4])
    return parent:unban(member)
end

function properties.guild(member)
    local parent = snowflakes.guild.get(member[4])
    return parent
end

function properties.user(member)
    return snowflakes.user.get(member[1])
end

function properties.name(member)
    return member[5] or member.user[4]
end

local function check_has_role(key, value, mem)
    return mem:has_role(key) and value
end

function methods.role_objects(member)
    return view.new(running():novus().cache.role, check_has_role, member)
end

function properties.highest_role(member)
    if #member[6] > 1 then
        sort(member[6], util.uint.id_sort)
        local state = running():novus()
        local position = huge
        local current
        for _, id in ipairs(member[6]) do
            local role = snowflakes.role.get_from(state, member[4], id)
            if role[8] < position then
                position = role[8]
                current = role
            end
        end
        return current
    else
        return snowflakes.role.get(member[4], member[6][1])
    end
end

function get_from(state, guild_id, id)
    local cache = state.cache.member
    if cache[id] then return cache[id]
    else
        local success, data, err = api.get_guild_member(state.api, guild_id, id)
        if success then
            data.guild_id = guild_id
            return new_from(state, data)
        else
            return nil, err
        end
    end
end

--end-module--
return _ENV