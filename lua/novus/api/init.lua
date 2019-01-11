--imports--
local cqueues = require"cqueues"
local errno = require"cqueues.errno"
local newreq = require "http.request"
local headers = require"http.headers"
local reason = require"http.h1_reason_phrases"
local httputil = require "http.util"
local json = require"rapidjson"
local util = require"novus.util"
local const = require"novus.const"
local lpeg = util.lpeg
local Date = util.Date
local JSON = "application/json"
local gettime = cqueues.monotime
local time, difftime, date = os.time, os.difftime, os.date
local insert, concat = table.insert, table.concat
local next, tonumber = next, tonumber
local setmetatable = setmetatable
local max = math.max
local print = print
local pcall = pcall
local type = type
local tostring = tostring

--start-module--
local _ENV = {}

URL = const.api.endpoint
USER_AGENT = ("DiscordBot (%s, %s) lua-version:\"%s\""):format(const.homepage,const.version, _VERSION )

local BOUNDARY1 = "novus" .. util.rid()
local BOUNDARY2 = "--" .. BOUNDARY1
local BOUNDARY3 = BOUNDARY2 .. "--"

local MULTIPART = ("multipart/form-data;boundary=%s"):format(BOUNDARY1)

local majorRoutes = {
    guilds = true, 
    channels = true, 
    webhooks = true
}

local with_payload = {
    PUT = true,
    PATCH = true,
    POST = true,
}

function mutex_cache() 
    return setmetatable({}, 
    {
        __mode = "v",
        __index = function (self, k)
            self[k] = util.mutex(k)
            return self[k]
        end
    })
end


local check_anywhere = util.compose(lpeg.check , lpeg.anywhere)
local digits = lpeg.digit^1
local message_endpoint = lpeg.check("/channels" * digits * "/messages/" * digits * -1)
local is_major_route = check_anywhere((lpeg.P"channels" + "guilds" + "webhooks") * "/" * digits * -1)
local ends_in_id = check_anywhere("/" * digits * -1)
local trailing_id = lpeg.anywhere(lpeg.C(lpeg.lazy(1,"/")) * digits * -1)

local function route_of(endpoint, method)
    if method == "DELETE" and message_endpoint:match(endpoint) then 
        return ("%s %s"):format(trailing_id:match(endpoint), method) 
    elseif endpoint:sub(1,9) == "/invites/" then 
        return "/invites/"
    elseif is_major_route:match(endpoint) then 
        return endpoint
    elseif ends_in_id:match(endpoint) then 
        return trailing_id:match(endpoint)
    else 
        return endpoint 
    end
end

local function attachFiles(payload, files) 
    local ret = {
        BOUNDARY2,
        "Content-Disposition:form-data;name=\"payload_json\"",
        "Content-Type:application/json\r\n",
        payload,
    }
    for i, v in ipairs(files) do
        insert(ret, BOUNDARY2)
        insert(ret, ("Content-Disposition:form-data;name=\"file%i\";filename=%q"):format(i, v[1]))
        insert(ret, "Content-Type:application/octet-stream\r\n")
        insert(ret, v[2])
    end
    insert(ret, BOUNDARY3)
    return concat(ret, "\r\n")
end

local token_check = lpeg.check(lpeg.patterns.token * -1)

function init(options)
    local state = {}
    if not (options.token and options.token:sub(1,4) == "Bot " and token_check:match(options.token:sub(5,-1))) then 
        return util.fatal("Please supply a bot token!")
    end
    state.token = options.token
    state.id = util.rid()
    state.routex = mutex_cache()
    state.global_lock = util.mutex()
    util.info("Initialized API-%s with TOKEN-%x", state.id, util.hash(state.token))
    return state
end

function request(state, method, endpoint, payload, query, files)
    if not cqueues.running() then 
        return util.fatal("Please call REST methods asynchronously.")
    end
    local url = URL .. endpoint
    if query and next(query) then
        url = ("%s?%s"):format(url, httputil.dict_query(query)) 
    end
    local req = newreq.new_from_uri(url)
    req.headers:append(":method", method)
    req.headers:upsert("user-agent", USER_AGENT)
    req.headers:append("authorization", state.token)
    if with_payload[method] then 
        payload = payload and json.encode(payload) or '{}'
        if files and next(files) then
            payload = attachFiles(payload, files)
            req.headers:append('content-type', MULTIPART)
        else
            req.headers:append('content-type', JSON)
        end
        req.headers:append("content-length", #payload)
        req:set_body(payload)
    end
    
    local route = route_of(endpoint, method)
    local routex = state.routex[route]
    
    state.global_lock:lock()
    if routex then routex:lock() end
    
    local success, data, err, delay, global = pcall(push, state, req, method, route, 0)
    if not success then 
        return util.fatal("api.push failed %q", tostring(data))
    end

    if global then 
        state.global_lock:unlockAfter(delay)
        if routex then routex:unlock() end
    else
        routex:unlockAfter(delay)
        state.global_lock:unlock()
    end

    return not err, data, err
end

function push(state, req, method,route, retries)
    local delay = 1 -- seconds
    local global = false -- whether the delay incurred is on the global limit

    local headers , stream , errno = req:go(10)
    
    if not headers and retries < const.max_retries then 
        util.warn("%s failed with (%s:%s, %q) retrying", method,route, errno[errno], errno.strerror(errno))
        cqueues.sleep(util.rand(1, 2))
        return push(state, req, method,route, retries+1)
    elseif not headers and retries >= const.max_retries then 
        return nil, errno.strerror(errno), delay, global
    end
    
    local code, rawcode = headers:get":status"
          rawcode, code = code, tonumber(code)

    local date = headers:get"date"
    local reset , remaining = headers:get"x-ratelimit-reset" , headers:get"x-ratelimit-remaining"
    if reset and remaining == '0' then 
        local dt = difftime(reset, Date.parseHeader(date))
        delay = max(dt, delay)
    end

    if headers:get"x-ratelimit-global" then 
        util.info("Route %s:%s has been downgraded to global limiting.", method, name)
        global = true 
        state.routex[route] = false -- downgrade the route
    end

    local raw = stream:get_body_as_string()
    local data = headers:get"content-type" == JSON and json.decode(raw) or raw
    if code < 300 then 
        return data, nil, delay, global
    else 
        if type(data) == 'table' then 
            local retry;
            if code == 429 then 
                delay = data.retry_after / 1000
                global = data.global
            elseif code == 502 then 
                delay = delay + util.rand(0 , 2)
            end
            retry = retries < 5 
            if retry then 
                util.warn("(%i, %q) :  retrying after %fsec : %s", code, reason[rawcode], delay, name)
                cqueues.sleep(delay)
                if global then state.global_lock:unlock() end
                return push(state, req, method,route, retries+1)
            end
        else
            util.error("(%i, %q) : %s", code, reason[rawcode], name)
            return nil, data, delay, global
        end
    end
end

-- generated functions

local endpoints = {
    CHANNEL                       = "/channels/%u",
    CHANNEL_INVITES               = "/channels/%u/invites",
    CHANNEL_MESSAGE               = "/channels/%u/messages/%u",
    CHANNEL_MESSAGES              = "/channels/%u/messages",
    CHANNEL_MESSAGES_BULK_DELETE  = "/channels/%u/messages/bulk-delete",
    CHANNEL_MESSAGE_REACTION      = "/channels/%u/messages/%u/reactions/%s",
    CHANNEL_MESSAGE_REACTIONS     = "/channels/%u/messages/%u/reactions",
    CHANNEL_MESSAGE_REACTION_ME   = "/channels/%u/messages/%u/reactions/%s/@me",
    CHANNEL_MESSAGE_REACTION_USER = "/channels/%u/messages/%u/reactions/%s/%u",
    CHANNEL_PERMISSION            = "/channels/%u/permissions/%u",
    CHANNEL_PIN                   = "/channels/%u/pins/%u",
    CHANNEL_PINS                  = "/channels/%u/pins",
    CHANNEL_RECIPIENT             = "/channels/%u/recipients/%u",
    CHANNEL_TYPING                = "/channels/%u/typing",
    CHANNEL_WEBHOOKS              = "/channels/%u/webhooks",
    GATEWAY                       = "/gateway",
    GATEWAY_BOT                   = "/gateway/bot",
    GUILD                         = "/guilds/%u",
    GUILDS                        = "/guilds",
    GUILD_AUDIT_LOGS              = "/guilds/%u/audit-logs",
    GUILD_BAN                     = "/guilds/%u/bans/%u",
    GUILD_BANS                    = "/guilds/%u/bans",
    GUILD_CHANNELS                = "/guilds/%u/channels",
    GUILD_EMBED                   = "/guilds/%u/embed",
    GUILD_EMOJI                   = "/guilds/%u/emojis/%u",
    GUILD_EMOJIS                  = "/guilds/%u/emojis",
    GUILD_INTEGRATION             = "/guilds/%u/integrations/%u",
    GUILD_INTEGRATIONS            = "/guilds/%u/integrations",
    GUILD_INTEGRATION_SYNC        = "/guilds/%u/integrations/%u/sync",
    GUILD_INVITES                 = "/guilds/%u/invites",
    GUILD_MEMBER                  = "/guilds/%u/members/%u",
    GUILD_MEMBERS                 = "/guilds/%u/members",
    GUILD_MEMBERS_ME_NICK         = "/guilds/%u/members/@me/nick",
    GUILD_MEMBER_ROLE             = "/guilds/%u/members/%u/roles/%u",
    GUILD_PRUNE                   = "/guilds/%u/prune",
    GUILD_REGIONS                 = "/guilds/%u/regions",
    GUILD_ROLE                    = "/guilds/%u/roles/%u",
    GUILD_ROLES                   = "/guilds/%u/roles",
    GUILD_VANITY_URL              = "/guilds/%u/vanity-url",
    GUILD_WEBHOOKS                = "/guilds/%u/webhooks",
    INVITE                        = "/invites/%s",
    OAUTH2_APPLICATIONS_ME        = "/oauth2/applications/@me",
    USER                          = "/users/%u",
    USERS_ME                      = "/users/@me",
    USERS_ME_CHANNELS             = "/users/@me/channels",
    USERS_ME_CONNECTIONS          = "/users/@me/connections",
    USERS_ME_GUILD                = "/users/@me/guilds/%u",
    USERS_ME_GUILDS               = "/users/@me/guilds",
    VOICE_REGIONS                 = "/voice/regions",
    WEBHOOK                       = "/webhooks/%u",
    WEBHOOK_TOKEN                 = "/webhooks/%u/%s",
    WEBHOOK_TOKEN_GITHUB          = "/webhooks/%u/%s/github",
    WEBHOOK_TOKEN_SLACK           = "/webhooks/%u/%s/slack",
}

function get_guild_audit_log(state, guild_id)
    local endpoint = endpoints.GUILD_AUDIT_LOGS:format(guild_id)
    return request(state, "GET", endpoint)
end

function get_channel(state, channel_id)
    local endpoint = endpoints.CHANNEL:format(channel_id)
    return request(state, "GET", endpoint)
end

function modify_channel(state, channel_id, payload)
    local endpoint = endpoints.CHANNEL:format(channel_id)
    return request(state, "PATCH", endpoint, payload)
end

function delete_channel(state, channel_id)
    local endpoint = endpoints.CHANNEL:format(channel_id)
    return request(state, "DELETE", endpoint)
end

function get_channel_messages(state, channel_id)
    local endpoint = endpoints.CHANNEL_MESSAGES:format(channel_id)
    return request(state, "GET", endpoint)
end

function get_channel_message(state, channel_id, message_id)
    local endpoint = endpoints.CHANNEL_MESSAGE:format(channel_id, message_id)
    return request(state, "GET", endpoint)
end

function create_message(state, channel_id, payload)
    local endpoint = endpoints.CHANNEL_MESSAGES:format(channel_id)
    return request(state, "POST", endpoint, payload)
end

function create_reaction(state, channel_id, message_id, emoji, payload)
    local endpoint = endpoints.CHANNEL_MESSAGE_REACTION_ME:format(channel_id, message_id, emoji)
    return request(state, "PUT", endpoint, payload)
end

function delete_own_reaction(state, channel_id, message_id, emoji)
    local endpoint = endpoints.CHANNEL_MESSAGE_REACTION_ME:format(channel_id, message_id, emoji)
    return request(state, "DELETE", endpoint)
end

function delete_user_reaction(state, channel_id, message_id, emoji, user_id)
    local endpoint = endpoints.CHANNEL_MESSAGE_REACTION_USER:format(channel_id, message_id, emoji, user_id)
    return request(state, "DELETE", endpoint)
end

function get_reactions(state, channel_id, message_id, emoji)
    local endpoint = endpoints.CHANNEL_MESSAGE_REACTION:format(channel_id, message_id, emoji)
    return request(state, "GET", endpoint)
end

function delete_all_reactions(state, channel_id, message_id)
    local endpoint = endpoints.CHANNEL_MESSAGE_REACTIONS:format(channel_id, message_id)
    return request(state, "DELETE", endpoint)
end

function edit_message(state, channel_id, message_id, payload)
    local endpoint = endpoints.CHANNEL_MESSAGE:format(channel_id, message_id)
    return request(state, "PATCH", endpoint, payload)
end

function delete_message(state, channel_id, message_id)
    local endpoint = endpoints.CHANNEL_MESSAGE:format(channel_id, message_id)
    return request(state, "DELETE", endpoint)
end

function bulk_delete_messages(state, channel_id, payload)
    local endpoint = endpoints.CHANNEL_MESSAGES_BULK_DELETE:format(channel_id)
    return request(state, "POST", endpoint, payload)
end

function edit_channel_permissions(state, channel_id, overwrite_id, payload)
    local endpoint = endpoints.CHANNEL_PERMISSION:format(channel_id, overwrite_id)
    return request(state, "PUT", endpoint, payload)
end

function get_channel_invites(state, channel_id)
    local endpoint = endpoints.CHANNEL_INVITES:format(channel_id)
    return request(state, "GET", endpoint)
end

function create_channel_invite(state, channel_id, payload)
    local endpoint = endpoints.CHANNEL_INVITES:format(channel_id)
    return request(state, "POST", endpoint, payload)
end

function delete_channel_permission(state, channel_id, overwrite_id)
    local endpoint = endpoints.CHANNEL_PERMISSION:format(channel_id, overwrite_id)
    return request(state, "DELETE", endpoint)
end

function trigger_typing_indicator(state, channel_id, payload)
    local endpoint = endpoints.CHANNEL_TYPING:format(channel_id)
    return request(state, "POST", endpoint, payload)
end

function get_pinned_messages(state, channel_id)
    local endpoint = endpoints.CHANNEL_PINS:format(channel_id)
    return request(state, "GET", endpoint)
end

function add_pinned_channel_message(state, channel_id, message_id, payload)
    local endpoint = endpoints.CHANNEL_PIN:format(channel_id, message_id)
    return request(state, "PUT", endpoint, payload)
end

function delete_pinned_channel_message(state, channel_id, message_id)
    local endpoint = endpoints.CHANNEL_PIN:format(channel_id, message_id)
    return request(state, "DELETE", endpoint)
end

function group_dM_add_recipient(state, channel_id, user_id, payload)
    local endpoint = endpoints.CHANNEL_RECIPIENT:format(channel_id, user_id)
    return request(state, "PUT", endpoint, payload)
end

function group_dM_remove_recipient(state, channel_id, user_id)
    local endpoint = endpoints.CHANNEL_RECIPIENT:format(channel_id, user_id)
    return request(state, "DELETE", endpoint)
end

function list_guild_emojis(state, guild_id)
    local endpoint = endpoints.GUILD_EMOJIS:format(guild_id)
    return request(state, "GET", endpoint)
end

function get_guild_emoji(state, guild_id, emoji_id)
    local endpoint = endpoints.GUILD_EMOJI:format(guild_id, emoji_id)
    return request(state, "GET", endpoint)
end

function create_guild_emoji(state, guild_id, payload)
    local endpoint = endpoints.GUILD_EMOJIS:format(guild_id)
    return request(state, "POST", endpoint, payload)
end

function modify_guild_emoji(state, guild_id, emoji_id, payload)
    local endpoint = endpoints.GUILD_EMOJI:format(guild_id, emoji_id)
    return request(state, "PATCH", endpoint, payload)
end

function delete_guild_emoji(state, guild_id, emoji_id)
    local endpoint = endpoints.GUILD_EMOJI:format(guild_id, emoji_id)
    return request(state, "DELETE", endpoint)
end

function create_guild(state, payload)
    local endpoint = endpoints.GUILDS
    return request(state, "POST", endpoint, payload)
end

function get_guild(state, guild_id)
    local endpoint = endpoints.GUILD:format(guild_id)
    return request(state, "GET", endpoint)
end

function modify_guild(state, guild_id, payload)
    local endpoint = endpoints.GUILD:format(guild_id)
    return request(state, "PATCH", endpoint, payload)
end

function delete_guild(state, guild_id)
    local endpoint = endpoints.GUILD:format(guild_id)
    return request(state, "DELETE", endpoint)
end

function get_guild_channels(state, guild_id)
    local endpoint = endpoints.GUILD_CHANNELS:format(guild_id)
    return request(state, "GET", endpoint)
end

function create_guild_channel(state, guild_id, payload)
    local endpoint = endpoints.GUILD_CHANNELS:format(guild_id)
    return request(state, "POST", endpoint, payload)
end

function modify_guild_channel_positions(state, guild_id, payload)
    local endpoint = endpoints.GUILD_CHANNELS:format(guild_id)
    return request(state, "PATCH", endpoint, payload)
end

function get_guild_member(state, guild_id, user_id)
    local endpoint = endpoints.GUILD_MEMBER:format(guild_id, user_id)
    return request(state, "GET", endpoint)
end

function list_guild_members(state, guild_id)
    local endpoint = endpoints.GUILD_MEMBERS:format(guild_id)
    return request(state, "GET", endpoint)
end

function add_guild_member(state, guild_id, user_id, payload)
    local endpoint = endpoints.GUILD_MEMBER:format(guild_id, user_id)
    return request(state, "PUT", endpoint, payload)
end

function modify_guild_member(state, guild_id, user_id, payload)
    local endpoint = endpoints.GUILD_MEMBER:format(guild_id, user_id)
    return request(state, "PATCH", endpoint, payload)
end

function modify_current_user_nick(state, guild_id, payload)
    local endpoint = endpoints.GUILD_MEMBERS_ME_NICK:format(guild_id)
    return request(state, "PATCH", endpoint, payload)
end

function add_guild_member_role(state, guild_id, user_id, role_id, payload)
    local endpoint = endpoints.GUILD_MEMBER_ROLE:format(guild_id, user_id, role_id)
    return request(state, "PUT", endpoint, payload)
end

function remove_guild_member_role(state, guild_id, user_id, role_id)
    local endpoint = endpoints.GUILD_MEMBER_ROLE:format(guild_id, user_id, role_id)
    return request(state, "DELETE", endpoint)
end

function remove_guild_member(state, guild_id, user_id)
    local endpoint = endpoints.GUILD_MEMBER:format(guild_id, user_id)
    return request(state, "DELETE", endpoint)
end

function get_guild_bans(state, guild_id)
    local endpoint = endpoints.GUILD_BANS:format(guild_id)
    return request(state, "GET", endpoint)
end

function get_guild_ban(state, guild_id, user_id)
    local endpoint = endpoints.GUILD_BAN:format(guild_id, user_id)
    return request(state, "GET", endpoint)
end

function create_guild_ban(state, guild_id, user_id, payload)
    local endpoint = endpoints.GUILD_BAN:format(guild_id, user_id)
    return request(state, "PUT", endpoint, payload)
end

function remove_guild_ban(state, guild_id, user_id)
    local endpoint = endpoints.GUILD_BAN:format(guild_id, user_id)
    return request(state, "DELETE", endpoint)
end

function get_guild_roles(state, guild_id)
    local endpoint = endpoints.GUILD_ROLES:format(guild_id)
    return request(state, "GET", endpoint)
end

function create_guild_role(state, guild_id, payload)
    local endpoint = endpoints.GUILD_ROLES:format(guild_id)
    return request(state, "POST", endpoint, payload)
end

function modify_guild_role_positions(state, guild_id, payload)
    local endpoint = endpoints.GUILD_ROLES:format(guild_id)
    return request(state, "PATCH", endpoint, payload)
end

function modify_guild_role(state, guild_id, role_id, payload)
    local endpoint = endpoints.GUILD_ROLE:format(guild_id, role_id)
    return request(state, "PATCH", endpoint, payload)
end

function delete_guild_role(state, guild_id, role_id)
    local endpoint = endpoints.GUILD_ROLE:format(guild_id, role_id)
    return request(state, "DELETE", endpoint)
end

function get_guild_prune_count(state, guild_id)
    local endpoint = endpoints.GUILD_PRUNE:format(guild_id)
    return request(state, "GET", endpoint)
end

function begin_guild_prune(state, guild_id, payload)
    local endpoint = endpoints.GUILD_PRUNE:format(guild_id)
    return request(state, "POST", endpoint, payload)
end

function get_guild_voice_regions(state, guild_id)
    local endpoint = endpoints.GUILD_REGIONS:format(guild_id)
    return request(state, "GET", endpoint)
end

function get_guild_invites(state, guild_id)
    local endpoint = endpoints.GUILD_INVITES:format(guild_id)
    return request(state, "GET", endpoint)
end

function get_guild_integrations(state, guild_id)
    local endpoint = endpoints.GUILD_INTEGRATIONS:format(guild_id)
    return request(state, "GET", endpoint)
end

function create_guild_integration(state, guild_id, payload)
    local endpoint = endpoints.GUILD_INTEGRATIONS:format(guild_id)
    return request(state, "POST", endpoint, payload)
end

function modify_guild_integration(state, guild_id, integration_id, payload)
    local endpoint = endpoints.GUILD_INTEGRATION:format(guild_id, integration_id)
    return request(state, "PATCH", endpoint, payload)
end

function delete_guild_integration(state, guild_id, integration_id)
    local endpoint = endpoints.GUILD_INTEGRATION:format(guild_id, integration_id)
    return request(state, "DELETE", endpoint)
end

function sync_guild_integration(state, guild_id, integration_id, payload)
    local endpoint = endpoints.GUILD_INTEGRATION_SYNC:format(guild_id, integration_id)
    return request(state, "POST", endpoint, payload)
end

function get_guild_embed(state, guild_id)
    local endpoint = endpoints.GUILD_EMBED:format(guild_id)
    return request(state, "GET", endpoint)
end

function modify_guild_embed(state, guild_id, payload)
    local endpoint = endpoints.GUILD_EMBED:format(guild_id)
    return request(state, "PATCH", endpoint, payload)
end

function get_guild_vanity_uRL(state, guild_id)
    local endpoint = endpoints.GUILD_VANITY_URL:format(guild_id)
    return request(state, "GET", endpoint)
end

function get_invite(state, invite_code)
    local endpoint = endpoints.INVITE:format(invite_code)
    return request(state, "GET", endpoint)
end

function delete_invite(state, invite_code)
    local endpoint = endpoints.INVITE:format(invite_code)
    return request(state, "DELETE", endpoint)
end

function get_current_user(state)
    local endpoint = endpoints.USERS_ME
    return request(state, "GET", endpoint)
end

function get_user(state, user_id)
    local endpoint = endpoints.USER:format(user_id)
    return request(state, "GET", endpoint)
end

function modify_current_user(state, payload)
    local endpoint = endpoints.USERS_ME
    return request(state, "PATCH", endpoint, payload)
end

function get_current_user_guilds(state)
    local endpoint = endpoints.USERS_ME_GUILDS
    return request(state, "GET", endpoint)
end

function leave_guild(state, guild_id)
    local endpoint = endpoints.USERS_ME_GUILD:format(guild_id)
    return request(state, "DELETE", endpoint)
end

function get_user_dMs(state)
    local endpoint = endpoints.USERS_ME_CHANNELS
    return request(state, "GET", endpoint)
end

function create_dM(state, payload)
    local endpoint = endpoints.USERS_ME_CHANNELS
    return request(state, "POST", endpoint, payload)
end

function create_group_dM(state, payload)
    local endpoint = endpoints.USERS_ME_CHANNELS
    return request(state, "POST", endpoint, payload)
end

function get_user_connections(state)
    local endpoint = endpoints.USERS_ME_CONNECTIONS
    return request(state, "GET", endpoint)
end

function list_voice_regions(state)
    local endpoint = endpoints.VOICE_REGIONS
    return request(state, "GET", endpoint)
end

function create_webhook(state, channel_id, payload)
    local endpoint = endpoints.CHANNEL_WEBHOOKS:format(channel_id)
    return request(state, "POST", endpoint, payload)
end

function get_channel_webhooks(state, channel_id)
    local endpoint = endpoints.CHANNEL_WEBHOOKS:format(channel_id)
    return request(state, "GET", endpoint)
end

function get_guild_webhooks(state, guild_id)
    local endpoint = endpoints.GUILD_WEBHOOKS:format(guild_id)
    return request(state, "GET", endpoint)
end

function get_webhook(state, webhook_id)
    local endpoint = endpoints.WEBHOOK:format(webhook_id)
    return request(state, "GET", endpoint)
end

function get_webhook_with_token(state, webhook_id, webhook_token)
    local endpoint = endpoints.WEBHOOK_TOKEN:format(webhook_id, webhook_token)
    return request(state, "GET", endpoint)
end

function modify_webhook(state, webhook_id, payload)
    local endpoint = endpoints.WEBHOOK:format(webhook_id)
    return request(state, "PATCH", endpoint, payload)
end

function modify_webhook_with_token(state, webhook_id, webhook_token, payload)
    local endpoint = endpoints.WEBHOOK_TOKEN:format(webhook_id, webhook_token)
    return request(state, "PATCH", endpoint, payload)
end

function delete_webhook(state, webhook_id)
    local endpoint = endpoints.WEBHOOK:format(webhook_id)
    return request(state, "DELETE", endpoint)
end

function delete_webhook_with_token(state, webhook_id, webhook_token)
    local endpoint = endpoints.WEBHOOK_TOKEN:format(webhook_id, webhook_token)
    return request(state, "DELETE", endpoint)
end

function execute_webhook(state, webhook_id, webhook_token, payload)
    local endpoint = endpoints.WEBHOOK_TOKEN:format(webhook_id, webhook_token)
    return request(state, "POST", endpoint, payload)
end

function execute_slack_compatible_webhook(state, webhook_id, webhook_token, payload)
    local endpoint = endpoints.WEBHOOK_TOKEN_SLACK:format(webhook_id, webhook_token)
    return request(state, "POST", endpoint, payload)
end

function execute_gitHub_compatible_webhook(state, webhook_id, webhook_token, payload)
    local endpoint = endpoints.WEBHOOK_TOKEN_GITHUB:format(webhook_id, webhook_token)
    return request(state, "POST", endpoint, payload)
end

function get_gateway(state)
    local endpoint = endpoints.GATEWAY
    return request(state, "GET", endpoint)
end

function get_gateway_bot(state)
    local endpoint = endpoints.GATEWAY_BOT
    return request(state, "GET", endpoint)
end

function get_current_application_information(state)
    local endpoint = endpoints.OAUTH2_APPLICATIONS_ME
    return request(state, "GET", endpoint)
end

--end-module--
return _ENV