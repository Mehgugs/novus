--imports--
local uint = require"novus.util.uint"
local api = require"novus.api"
local snowflake = require"novus.snowflakes"
local perms = require"novus.util.permission"
local cqueues = require"cqueues"
local json = require"cjson"
local ipairs = ipairs
local null = json.null
local running = cqueues.running
local snowflakes = snowflake.snowflakes
--start-module--
return function (_ENV)

    schema {
        "guild_id" --7
       ,"name" --8
       ,"position" --9
       ,"parent_id" --10
       ,"permission_overwrites" --11
   }

    processor.parent_id = uint.touint
    processor.guild_id  = uint.touint

    function processor.overwrites (o)
        if o then
            local new = {}
            for _, ow in ipairs(o) do
                ow.id = uint(ow.id)
                ow.allow = perms.new(ow.allow)
                ow.deny =  perms.new(ow.deny)
                new[ow.id] = ow
            end
            return new
        end
    end

    function methods.set_name(channel, name)
        return modify(channel, {name = name or null})
    end

    function methods.set_category(channel, id)
        id = snowflake.id(id)
        return modify(channel, {parent_id = id or null})
    end

    function methods.invites(channel)
        local state = running():novus()
        local success, data, err = api.get_channel_invites(state.api, channel[1])
        if success and data then
            local out = {}
            for i, invite in ipairs(data) do
                out[i] = snowflakes.invite.new_from(state, invite)
            end
            return out
        else
            return false, err
        end
    end

    local function blank_overwrite(channel, id, type)
        channel.permission_overwrites[id] = {
             id = id
            ,type = type
            ,allow = perms.new()
            ,deny =  perms.new()
        }
        return channel.permission_overwrites[id]
    end

    local allowed = {
         member = true
        ,role = true
    }

    function methods.overwrite(channel, user_role)
        local id = snowflake.id(user_role)
        local typ = id and user_role.kind
        if typ and allowed[typ] then
            return channel.permission_overwrites[id] or blank_overwrite(channel, id, typ)
        end
    end

    function methods.update_overwrite(channel, ow)
        local state = running():novus()
        local success, _, err = api.edit_channel_permissions(state.api, channel[1], ow.id, {
            type = ow.type,
            id = ow.id,
            allow = perms.resolve(ow.allow),
            deny = perms.resolve(ow.deny)
        })
        if success then
            return true
        else
            return false, err
        end
    end

    function methods.move_up(channel, by)
        return channel.guild:move_channel_up(channel, by)
    end

    function methods.move_down(channel, by)
        return channel.guild:move_channel_down(channel, by)
    end

    methods.move = methods.move_up

    function properties.guild(channel)
        return snowflakes.guild.get(channel.guild_id)
    end

    function properties.category(channel)
        if channel.parent_id then
            return snowflakes.channel.get(channel.parent_id)
        end
    end

    return _ENV
end
