--imports--
local api = require"novus.api"
local util = require"novus.snowflakes.helpers"
local snowflake = require"novus.snowflakes.snowflake"
local cqueues = require"cqueues"
local setmetatable = setmetatable
local gettime = cqueues.monotime
local running = cqueues.running
local snowflakes = snowflake.snowflakes
local insert, sort = table.insert, table.sort
local huge = math.huge
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

function new_from(state, payload)
    local user = payload.user
    local id = util.uint(user.id)
    if not state.cache.user[id] then
        snowflakes.user.new_from(state, user)
    end
    return setmetatable({
         id
        ,gettime()
        ,state.cache.methods.member
        ,payload.guild_id
        ,payload.nick
        ,payload.roles
        ,payload.joined_at
        ,payload.deaf
        ,payload.mute
        ,payload.channel_id
    }, _ENV)
end

function methods.add_role(member, id)
    id = snowflake.id(id)
    if util.includes(member[6], id) then return true end
    local state = running():novus()
    local success, _, err = api.add_guild_member_role(state.api, member[4], member[1], id)
    if success then
        insert(member[6], id)
    end
    return success, err
end

function methods.remove_role(member, id)
    id = snowflake.id(id)
    if not util.includes(member[6], id) then return true end
    local state = running():novus()
    local success, _, err = api.remove_guild_member_role(state.api, member[4], member[1], id)
    if success then
        member[6] = util.filter(member[6], util.not_eq, id)
    end
    return success, err
end

function methods.has_role(member, id) return util.includes(member[6], id) end

function methods.set_nickname(member, nick)
    nick = nick or ''
    local state = running():novus()
    local success, _, err
    if member[1] == state.app.id then
        success, _, err = api.modify_current_user_nick(state.api, member[4], member[1], {nick = nick})
    else
        success, _, err = api.modify_guild_member(state.api, member[4], member[1], {nick = nick})
    end
    if success then
        member[5] = nick ~= '' and nick or nil
        return true
    else
        return false, err
    end
end

function methods.set_voice_channel(member, id)
    local state = running():novus()
    local success, data, err =  api.modify_guild_member(state.api, member[4], member[1], {channel_id = id})
    if success and data then
        return true
    else
        return false, err
    end
end

function methods.mute(member)
    local state = running():novus()
    local success, data, err =  api.modify_guild_member(state.api, member[4], member[1], {mute = true})
    if success and data then
        member[9] = true
        return true
    else
        return false, err
    end
end

function methods.deafen(member)
    local state = running():novus()
    local success, data, err =  api.modify_guild_member(state.api, member[4], member[1], {deaf = true})
    if success and data then
        member[8] = true
        return true
    else
        return false, err
    end
end

function methods.unmute(member)
    local state = running():novus()
    local success, data, err =  api.modify_guild_member(state.api, member[4], member[1], {mute = false})
    if success and data then
        member[9] = false
        return true
    else
        return false, err
    end
end

function methods.undeafen(member)
    local state = running():novus()
    local success, data, err =  api.modify_guild_member(state.api, member[4], member[1], {deaf = false})
    if success and data then
        member[8] = false
        return true
    else
        return false, err
    end
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
    local cache = state.cache[__name]
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