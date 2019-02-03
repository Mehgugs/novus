--imports--
local api = require"novus.api"
local util = require"novus.snowflakes.helpers"
local snowflake = require"novus.snowflakes"
local permission = require"novus.util.permission"
local modifiable = require"novus.snowflakes.mixins.modifiable"
local cqueues = require"cqueues"
local null = require"cjson".null
local setmetatable = setmetatable
local gettime = cqueues.monotime
local running = cqueues.running
local snowflakes = snowflake.snowflakes
--start-module--
local _ENV = snowflake "role"

schema {
     "guild_id" --4
    ,"name" --5
    ,"color" --6
    ,"hoisted" --7
    ,"position" --8
    ,"permissions" --9
    ,"managed" --10
    ,"is_mentionable" -- 11
}

function new_from( state, payload )
    return setmetatable({
         util.uint(payload.id)
        ,gettime()
        ,state.cache.methods.role
        ,payload.guild_id
        ,payload.name
        ,payload.color
        ,payload.hoist
        ,payload.position
        ,payload.permissions
        ,payload.managed
        ,payload.mentionable
    }, _ENV)
end

function methods.delete(role)
    local state = running():novus()
    local success, data, err = api.delete_guild_role(state.api, role[4], role[1])
    if success and data then
        return true
    else
        return false, err
    end
end

_ENV = modifiable(_ENV,  api.modify_guild_role) -- endow with modify

function methods.set_name(role, name)
    return modify(role, {name = name or null})
end

function methods.set_color(role, color)
    return modify(role, {color = color or null})
end

function methods.set_permissions(role, p)
    return modify(role, {permissions = p or null})
end

function methods.hoist(role)
    return modify(role, {hoist = true})
end

function methods.unhoist(role)
    return modify(role, {hoist = false})
end

function methods.mentionable(role)
    return modify(role, {mentionable = true})
end

function methods.unmentionable(role)
    return modify(role, {mentionable = true})
end

function methods.enable(role, ...)
    return methods.set_permissions(role, permission.enable(role[9], ...))
end

function methods.disable(role, ...)
    return methods.set_permissions(role, permission.disable(role[9], ...))
end

function methods.can(role, ...)
    return permission.contains(role[9], ...)
end

function properties.guild(role)
    local parent = snowflakes.guild.get(role[4])
    return parent
end

function properties.mention(role)
    return "<@&%s>" % role[1]
end

function get_from(state, guild_id, id)
    local cache = state.cache[__name]
    if cache[id] then return cache[id]
    else
        local success, data, err = api.get_guild_role(state.api, guild_id, id)
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